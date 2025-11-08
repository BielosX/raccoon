import { BrowserRouter } from "react-router";
import { CognitoProviderWithNavigate } from "./CognitoProviderWithNavigate.tsx";
import { AvatarProvider } from "./AvatarProvider.tsx";
import "./App.css";
import { CognitoWellKnownProvider } from "./CognitoWellKnownProvider.tsx";
import { AppContent } from "./AppContent.tsx";

function App() {
  const idpUrl: string = import.meta.env.VITE_IDP_URL;

  return (
    <div className="font-(family-name:--font-roboto)">
      <BrowserRouter>
        <CognitoWellKnownProvider idpUrl={idpUrl}>
          <CognitoProviderWithNavigate>
            <AvatarProvider>
              <AppContent />
            </AvatarProvider>
          </CognitoProviderWithNavigate>
        </CognitoWellKnownProvider>
      </BrowserRouter>
    </div>
  );
}

export default App;
