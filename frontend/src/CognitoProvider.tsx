import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useState,
} from "react";
import { v4 as uuidv4 } from "uuid";
import { useCognitoWellKnown } from "./CognitoWellKnownProvider.tsx";
import { jwtVerify } from "jose";

type CognitoContextType = {
  loginWithRedirect: (appState?: AppState) => void;
  onRedirectCallback: (appState: AppState) => void;
  logout: (appState?: AppState) => void;
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
  logout: () => {},
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
  logoutPath?: string;
  tokenPath?: string;
  userInfoPath?: string;
  clientId: string;
  scope: string;
  logoutCallbackPath?: string;
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
  id_token?: string;
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
  logoutPath = "/logout",
  tokenPath = "/oauth2/token",
  userInfoPath = "/oauth2/userInfo",
  clientId,
  scope,
  onRedirectCallback,
  children,
  callbackPath = "/callback",
  logoutCallbackPath = "/logout",
  errorPath = "/error",
}: CognitoProviderProps) => {
  const [accessToken, setAccessToken] = useState<AccessTokenDetails | null>(
    null,
  );
  const [userInfo, setUserInfo] = useState<UserInfoDetails | null>();
  const { getKey, getOpenIdConfig } = useCognitoWellKnown();
  const refreshTokenKey = "refreshToken";
  const stateNonceKey = "stateNonce";
  const tokenNonceKey = "tokenNonce";
  const redirectUri = `${window.location.origin}${callbackPath}`;
  const logoutCallbackUri = `${window.location.origin}${logoutCallbackPath}`;
  const loginUrl = `${domainUrl}${loginPath}`;
  const logoutUrl = `${domainUrl}${logoutPath}`;
  const tokenUrl = `${domainUrl}${tokenPath}`;
  const userInfoUrl = `${domainUrl}${userInfoPath}`;
  const isAuthenticated = accessToken !== null;

  const stateWithNonce = (state?: AppState): string => {
    const nonce = uuidv4();
    localStorage.setItem(stateNonceKey, nonce);
    const stateWithNonce = { ...state, __nonce: nonce };
    return btoa(JSON.stringify(stateWithNonce));
  };

  const loginWithRedirect = (state: AppState = { returnTo: "/" }) => {
    setAccessToken(null);
    localStorage.removeItem(refreshTokenKey);
    const authState = stateWithNonce(state);
    const nonce = uuidv4();
    localStorage.setItem(tokenNonceKey, nonce);
    const params = new URLSearchParams({
      response_type: "code",
      client_id: clientId,
      redirect_uri: redirectUri,
      state: authState,
      scope: scope,
      nonce,
    });
    const goTo = `${loginUrl}?${params.toString()}`;
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

  const verifyIdToken = async (token: string): Promise<boolean> => {
    const config = await getOpenIdConfig();
    try {
      const result = await jwtVerify(token, getKey, {
        issuer: config.issuer,
      });
      const tokenNonce = localStorage.getItem(tokenNonceKey);
      if (!tokenNonce) {
        console.error("Nonce not found in localStorage");
        return false;
      }
      if (result.payload["nonce"] != tokenNonce) {
        console.error("Nonce does not match");
        return false;
      }
    } catch (error) {
      console.error(`jwtVerify failed with error: ${error}`);
      return false;
    }
    console.log("Id Token is correct");
    return true;
  };

  const fetchToken = async (code: string, appState: AppState) => {
    const result = await callTokenEndpoint({
      grant_type: "authorization_code",
      client_id: clientId,
      redirect_uri: redirectUri,
      code: code,
    });
    if (result.id_token) {
      console.log("Validating Id Token");
      const valid = await verifyIdToken(result.id_token);
      if (!valid) {
        console.error("Received Id Token is invalid");
        toErrorPage();
        return;
      }
    }
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

  const logout = (appState: AppState = { returnTo: "/" }) => {
    const authState = stateWithNonce(appState);
    const params = new URLSearchParams({
      client_id: clientId,
      logout_uri: logoutCallbackUri,
      state: authState,
    });
    const goTo = `${logoutUrl}?${params.toString()}`;
    console.log(`Redirect to ${redirectUri}`);
    window.location.href = goTo;
  };

  const getAccessToken = async (
    appState: AppState = { returnTo: "/" },
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
    appState: AppState = { returnTo: "/" },
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

  const verifyState = (params: URLSearchParams): AppState | undefined => {
    const authNonce = localStorage.getItem(stateNonceKey);
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
    return decodedState;
  };

  useEffect(() => {
    if (window.location.pathname === callbackPath) {
      const params = new URLSearchParams(window.location.search);
      const state = verifyState(params);
      const code = params.get("code");
      if (!code) {
        console.error("code query param not found");
        toErrorPage();
        return;
      }
      fetchToken(code as string, state as AppState).catch(() => {
        console.error("Failed to fetch token");
        toErrorPage();
        return;
      });
    }
    if (window.location.pathname === logoutCallbackPath) {
      const params = new URLSearchParams(window.location.search);
      const state = verifyState(params);
      setAccessToken(null);
      localStorage.removeItem(refreshTokenKey);
      onRedirectCallback(state as AppState);
    }
  }, [callbackPath, errorPath, logoutCallbackPath]);

  return (
    <CognitoContext.Provider
      value={{
        loginWithRedirect,
        onRedirectCallback,
        isAuthenticated,
        getAccessToken,
        getUserInfo,
        logout,
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
