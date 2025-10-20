import { Spinner } from "../components/Spinner.tsx";
import type { FC } from "react";

export const LoadingPage: FC = () => {
  return (
    <div className="h-screen flex items-center justify-center">
      <Spinner size={16} />
    </div>
  )
};
