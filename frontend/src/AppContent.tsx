import { useCognitoWellKnown } from "./CognitoWellKnownProvider.tsx";
import { TopBar } from "./components/TopBar.tsx";
import { Route, Routes } from "react-router";
import { MainPage } from "./pages/MainPage.tsx";
import { LoadingPage } from "./pages/LoadingPage.tsx";
import { Spinner } from "./components/Spinner.tsx";

export const AppContent = () => {
  const { isLoading } = useCognitoWellKnown();

  const content = (
    <>
      <TopBar />
      <Routes>
        <Route path="/" element={<MainPage />} />
        <Route path="/callback" element={<LoadingPage />} />
        <Route path="/logout" element={<LoadingPage />} />
      </Routes>
    </>
  );

  return isLoading ? <Spinner size={16} /> : content;
};
