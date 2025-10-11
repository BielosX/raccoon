import { BrowserRouter, Route, Routes } from "react-router";
import { MainPage } from "./pages/MainPage.tsx";
import { CallbackPage } from "./pages/CallbackPage.tsx";
import { CognitoProviderWithNavigate } from "./CognitoProviderWithNavigate.tsx";
import {VersionPage} from "./pages/VersionPage.tsx";

function App() {
  return (
    <BrowserRouter>
      <CognitoProviderWithNavigate>
        <Routes>
          <Route path="/" element={<MainPage />} />
          <Route path="/version" element={<VersionPage />} />
          <Route path="/callback" element={<CallbackPage />} />
        </Routes>
      </CognitoProviderWithNavigate>
    </BrowserRouter>
  );
}

export default App;
