import { BrowserRouter, Route, Routes } from "react-router";
import { MainPage } from "./pages/MainPage.tsx";
import { LoadingPage } from "./pages/LoadingPage.tsx";
import { CognitoProviderWithNavigate } from "./CognitoProviderWithNavigate.tsx";
import { AvatarProvider } from "./AvatarProvider.tsx";
import "./App.css";
import { TopBar } from "./components/TopBar.tsx";
import { CognitoWellKnownProvider } from "./CognitoWellKnownProvider.tsx";

function App() {
  const idpUrl: string = import.meta.env.VITE_IDP_URL;

  return (
    <div className="font-(family-name:--font-roboto)">
      <BrowserRouter>
        <CognitoWellKnownProvider idpUrl={idpUrl}>
          <CognitoProviderWithNavigate>
            <AvatarProvider>
              <TopBar />
              <Routes>
                <Route path="/" element={<MainPage />} />
                <Route path="/callback" element={<LoadingPage />} />
                <Route path="/logout" element={<LoadingPage />} />
              </Routes>
            </AvatarProvider>
          </CognitoProviderWithNavigate>
        </CognitoWellKnownProvider>
      </BrowserRouter>
    </div>
  );
}

export default App;
