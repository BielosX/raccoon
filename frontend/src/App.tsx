import { BrowserRouter, Route, Routes } from "react-router";
import { MainPage } from "./pages/MainPage.tsx";
import { LoadingPage } from "./pages/LoadingPage.tsx";
import { CognitoProviderWithNavigate } from "./CognitoProviderWithNavigate.tsx";
import { AvatarProvider } from "./AvatarProvider.tsx";
import "./App.css";
import { TopBar } from "./components/TopBar.tsx";

function App() {
  return (
    <div className="font-(family-name:--font-roboto)">
      <BrowserRouter>
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
      </BrowserRouter>
    </div>
  );
}

export default App;
