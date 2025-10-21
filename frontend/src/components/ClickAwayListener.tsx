import type { ReactNode } from "react";
import { useOutsideClick } from "../hooks/useOutsideClick.ts";

type ClickAwayListenerProps = {
  children?: ReactNode;
  onClickAway: () => void;
};

export const ClickAwayListener = ({
  children,
  onClickAway,
}: ClickAwayListenerProps) => {
  const ref = useOutsideClick(() => {
    onClickAway();
  });
  return <div ref={ref}>{children}</div>;
};
