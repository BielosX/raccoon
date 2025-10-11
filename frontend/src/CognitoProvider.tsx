import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useState,
} from "react";
import { v4 as uuidv4 } from "uuid";

type CognitoContextType = {
  loginWithRedirect: (appState?: AppState) => void;
  onRedirectCallback: (appState: AppState) => void;
  getAccessToken: (appState?: AppState) => Promise<string>;
  getUserInfo: (appState?: AppState) => Promise<UserInfo>;
  isAuthenticated: boolean;
};

type AccessTokenDetails = {
  accessToken: string;
  expiresAt: number;
};

const CognitoContext = createContext<CognitoContextType>({
  loginWithRedirect: () => {},
  onRedirectCallback: (_: AppState) => {},
  getAccessToken: () => {
    return Promise.resolve("");
  },
  getUserInfo: () => {
    return Promise.resolve({ sub: "" });
  },
  isAuthenticated: false,
});

export type CognitoProviderProps = {
  children: ReactNode;
  domainUrl: string;
  loginPath?: string;
  tokenPath?: string;
  userInfoPath?: string;
  clientId: string;
  scope: string;
  callbackPath?: string;
  errorPath?: string;
  onRedirectCallback: (appState: AppState) => void;
};

export type AppState = {
  returnTo?: string;
  [key: string]: string | undefined;
};

type TokenResponse = {
  access_token: string;
  id_token: string;
  refresh_token?: string;
  expires_in: number;
  token_type: string;
};

type TokenEndpointParams = {
  grant_type: string;
  client_id: string;
  redirect_uri?: string;
  code?: string;
  refresh_token?: string;
};

export type UserInfo = {
  sub: string;
  email?: string;
  email_verified?: boolean;
  name?: string;
  username?: string;
  given_name?: string;
  family_name?: string;
  updated_at?: number;
  address?: Record<string, any>;
  [key: string]: string | number | boolean | object | undefined;
};

type UserInfoDetails = {
  info: UserInfo;
  expiresAt: number;
};

const FIVE_MINUTES = 5 * 60 * 1000;

export const CognitoProvider = ({
  domainUrl,
  loginPath = "/login",
  tokenPath = "/oauth2/token",
  userInfoPath = "/oauth2/userInfo",
  clientId,
  scope,
  onRedirectCallback,
  children,
  callbackPath = "/callback",
  errorPath = "/error",
}: CognitoProviderProps) => {
  const [accessToken, setAccessToken] = useState<AccessTokenDetails | null>(
    null,
  );
  const [userInfo, setUserInfo] = useState<UserInfoDetails | null>();
  const refreshTokenKey = "refreshToken";
  const authNonceKey = "authNonce";
  const redirectUri = `${window.location.origin}${callbackPath}`;
  const loginUrl = `${domainUrl}${loginPath}`;
  const tokenUrl = `${domainUrl}${tokenPath}`;
  const userInfoUrl = `${domainUrl}${userInfoPath}`;
  const isAuthenticated = accessToken !== null;

  const loginWithRedirect = (
    state: AppState = { returnTo: window.location.origin },
  ) => {
    setAccessToken(null);
    localStorage.removeItem(refreshTokenKey);
    const nonce = uuidv4();
    localStorage.setItem(authNonceKey, nonce);
    const stateWithNonce = { ...state, __nonce: nonce };
    const authState = btoa(JSON.stringify(stateWithNonce));
    const encodedClientId = encodeURIComponent(clientId);
    const encodedUri = encodeURIComponent(redirectUri);
    const encodedState = encodeURIComponent(authState);
    const encodedScope = encodeURIComponent(scope);
    const goTo = `${loginUrl}?response_type=code&client_id=${encodedClientId}&redirect_uri=${encodedUri}&state=${encodedState}&scope=${encodedScope}`;
    console.log(`Redirect to ${redirectUri}`);
    window.location.href = goTo;
  };

  const storeTokenResponse = (response: TokenResponse) => {
    if (response.refresh_token) {
      localStorage.setItem(refreshTokenKey, response.refresh_token);
    }
    setAccessToken({
      accessToken: response.access_token,
      expiresAt: response.expires_in * 1000 + Date.now(),
    });
  };

  const callTokenEndpoint = async (
    params: TokenEndpointParams,
  ): Promise<TokenResponse> => {
    const response = await fetch(tokenUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: new URLSearchParams(params),
    });
    if (!response.ok) {
      const text = await response.text();
      throw new Error(`Token endpoint failed: ${text}`);
    }
    return response.json();
  };

  const fetchToken = async (code: string, appState: AppState) => {
    const result = await callTokenEndpoint({
      grant_type: "authorization_code",
      client_id: clientId,
      redirect_uri: redirectUri,
      code: code,
    });
    storeTokenResponse(result);
    onRedirectCallback(appState);
  };

  const doRefreshToken = async (
    refreshToken: string,
  ): Promise<TokenResponse> => {
    return await callTokenEndpoint({
      grant_type: "refresh_token",
      client_id: clientId,
      refresh_token: refreshToken,
    });
  };

  const getAccessToken = async (
    appState: AppState = { returnTo: window.location.origin },
  ): Promise<string> => {
    const now = Date.now();
    if (accessToken === null || now > accessToken.expiresAt) {
      const refreshToken = localStorage.getItem(refreshTokenKey);
      if (refreshToken === null) {
        loginWithRedirect(appState);
        return "";
      }
      try {
        const result = await doRefreshToken(refreshToken);
        storeTokenResponse(result);
        return result.access_token;
      } catch (_) {
        loginWithRedirect(appState);
        return "";
      }
    }
    return accessToken.accessToken;
  };

  const toErrorPage = () => {
    window.location.href = `${window.location.origin}${errorPath}`;
  };

  const getUserInfo = async (
    appState: AppState = { returnTo: window.location.origin },
  ): Promise<UserInfo> => {
    if (Date.now() > (userInfo?.expiresAt ?? 0)) {
      const token = await getAccessToken(appState);
      const response = await fetch(userInfoUrl, {
        method: "GET",
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      if (!response.ok) {
        throw new Error("Could not get User Info");
      }
      const info: UserInfo = await response.json();
      setUserInfo({ info, expiresAt: Date.now() + FIVE_MINUTES });
      return info;
    }
    return userInfo?.info as UserInfo;
  };

  useEffect(() => {
    if (window.location.pathname === callbackPath) {
      const params = new URLSearchParams(window.location.search);
      const authNonce = localStorage.getItem(authNonceKey);
      if (!authNonce) {
        console.error("authNonce not found in localStorage");
        toErrorPage();
        return;
      }
      const state = params.get("state");
      if (!state) {
        console.error("state query param not found");
        toErrorPage();
        return;
      }
      const decodedState: AppState & { __nonce: string } = JSON.parse(
        atob(state as string),
      );
      if (authNonce !== decodedState.__nonce) {
        console.error("received nonce does not match stored one");
        toErrorPage();
        return;
      }
      const code = params.get("code");
      if (!code) {
        console.error("code query param not found");
        toErrorPage();
        return;
      }
      fetchToken(code as string, decodedState).catch(() => {
        console.error("Failed to fetch token");
        toErrorPage();
        return;
      });
    }
  }, [callbackPath, errorPath]);

  return (
    <CognitoContext.Provider
      value={{
        loginWithRedirect,
        onRedirectCallback,
        isAuthenticated,
        getAccessToken,
        getUserInfo,
      }}
    >
      {children}
    </CognitoContext.Provider>
  );
};

export const useCognito = () => {
  const context = useContext(CognitoContext);
  if (!context) {
    throw new Error("useCognito must be used within a CognitoProvider");
  }
  return context;
};
