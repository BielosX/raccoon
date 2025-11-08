import {
  createContext,
  type ReactNode,
  useContext,
  useEffect,
  useState,
} from "react";
import {
  type CryptoKey,
  type FlattenedJWSInput,
  importJWK,
  type JSONWebKeySet,
  type JWK,
  type JWSHeaderParameters,
} from "jose";
import { usePersistentState } from "./hooks/usePersistentState.ts";

type CognitoWellKnownProviderProps = {
  children: ReactNode;
  idpUrl: string;
};

type CognitoWellKnownContextType = {
  isLoading: boolean;
  getOpenIdConfig: () => Promise<OpenIdConfigurationResponse>;
  getKey: (
    header?: JWSHeaderParameters,
    token?: FlattenedJWSInput,
  ) => Promise<CryptoKey>;
};

const CognitoWellKnownContext = createContext<CognitoWellKnownContextType>({
  isLoading: false,
  getOpenIdConfig: async () => {
    return Promise.reject();
  },
  getKey: () => {
    return Promise.reject();
  },
});

type OpenIdConfigurationResponse = {
  issuer: string;
};

type StoredKeys = {
  [key: string]: JWK[];
};

export const CognitoWellKnownProvider = ({
  children,
  idpUrl,
}: CognitoWellKnownProviderProps) => {
  const [loading, setLoading] = useState<boolean>(true);
  const [keys, setKeys] = usePersistentState<StoredKeys>("jwks");
  const [config, setConfig] =
    usePersistentState<OpenIdConfigurationResponse>("openIdConfig");
  const prefix = `${idpUrl}/.well-known`;

  const getKeys = async (): Promise<JSONWebKeySet> => {
    const response = await fetch(`${prefix}/jwks.json`, {
      method: "GET",
    });
    return await response.json();
  };

  const getConfig = async (): Promise<OpenIdConfigurationResponse> => {
    const response = await fetch(`${prefix}/openid-configuration`, {
      method: "GET",
    });
    return await response.json();
  };

  const kidToKeys = (keys: JWK[]): StoredKeys => {
    return keys.reduce((acc, value) => {
      if (value.kid) {
        const kid = value.kid;
        const group = acc[kid] ?? [];
        group.push(value);
        acc[kid] = group;
      }
      return acc;
    }, {} as StoredKeys);
  };

  const getWellKnown = async () => {
    if (keys && config) {
      console.log("JWKS and config already fetched");
      return;
    }
    const [k, c] = await Promise.all([getKeys(), getConfig()]);
    setConfig(c);
    setKeys(kidToKeys(k.keys));
    console.log(".well-known fetched");
  };

  const getJwk = (
    keys: StoredKeys,
    kid: string,
    alg: string,
  ): JWK | undefined => {
    return (keys[kid] ?? []).find((v) => v.alg === alg);
  };

  const getKey = async (
    header?: JWSHeaderParameters,
    token?: FlattenedJWSInput,
  ): Promise<CryptoKey> => {
    const { alg, kid } = { ...header, ...token?.header };
    console.log(`Fetching JWK for alg ${alg} and kid ${kid}`);
    if (kid && alg) {
      let jwks = keys;
      if (!jwks) {
        const fetchedJwks = await getKeys();
        jwks = kidToKeys(fetchedJwks.keys);
        setKeys(jwks);
      }
      const jwk = getJwk(jwks, kid, alg);
      if (jwk) {
        console.log(`JWK for kid ${kid} found`);
        return (await importJWK(jwk)) as CryptoKey;
      } else {
        console.log(`JWK for kid ${kid} not found. Trying to fetch new ones`);
        const keys = await getKeys();
        const mapped = kidToKeys(keys.keys);
        setKeys(mapped);
        const jwk = getJwk(mapped, kid, alg);
        if (jwk) {
          console.log(`JWK for kid ${kid} found`);
          return (await importJWK(jwk)) as CryptoKey;
        }
      }
    }
    console.log(`JWK for alg ${alg} and kid ${kid} not found`);
    return Promise.reject(
      new Error(`Key not found for kid ${kid} and alg ${alg}`),
    );
  };

  const getOpenIdConfig = async (): Promise<OpenIdConfigurationResponse> => {
    if (!config) {
      const cfg = await getConfig();
      setConfig(cfg);
      return cfg;
    }
    return config;
  };

  useEffect(() => {
    getWellKnown()
      .then(() => {
        setLoading(false);
      })
      .catch(() => {
        console.error(`Unable to fetch data from ${prefix}`);
      });
  }, [idpUrl]);

  return (
    <CognitoWellKnownContext.Provider
      value={{
        getOpenIdConfig,
        getKey,
        isLoading: loading,
      }}
    >
      {children}
    </CognitoWellKnownContext.Provider>
  );
};

export const useCognitoWellKnown = () => {
  const context = useContext(CognitoWellKnownContext);
  if (!context) {
    throw new Error(
      "useCognitoWellKnown must be used within a CognitoWellKnownProvider",
    );
  }
  return context;
};
