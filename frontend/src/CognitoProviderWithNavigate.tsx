import { type AppState, CognitoProvider } from "./CognitoProvider.tsx";
import type { ReactNode } from "react";
import { useNavigate } from "react-router";

export const CognitoProviderWithNavigate = ({
  children,
}: {
  children: ReactNode;
}) => {
  const navigate = useNavigate();
  const domainUrl: string = import.meta.env.VITE_COGNITO_DOMAIN_URL;
  const clientId: string = import.meta.env.VITE_COGNITO_CLIENT_ID;

  return (
    <CognitoProvider
      domainUrl={domainUrl}
      loginPath="/login"
      tokenPath="/oauth2/token"
      clientId={clientId}
      scope={"openid profile"}
      onRedirectCallback={function (state: AppState): void {
        const returnTo = state?.returnTo ?? window.location.pathname;
        console.log(`Entered callback, navigating to: ${returnTo}`);
        navigate(returnTo);
      }}
    >
      {children}
    </CognitoProvider>
  );
};
