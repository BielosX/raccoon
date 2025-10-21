import type { ReactNode } from "react";

type MenuProps = {
  children?: ReactNode;
};

export const Menu = ({ children }: MenuProps) => {
  const classNames = [
    "pl-0",
    "pr-0",
    "pt-2",
    "pb-2",
    "rounded-md",
    "flex",
    "flex-col",
    "items-stretch",
    "justify-center",
    "absolute",
    "flex-nowrap",
    "whitespace-nowrap",
    "top-full",
    "bg-white",
    "mt-1",
    "right-2",
    "shadow-[0_0_6px_4px_rgb(0_0_0_/_0.1)]",
  ];
  return <div className={classNames.join(" ")}>{children}</div>;
};

type MenuItemProps = {
  children?: ReactNode;
  onClick?: () => void;
};

export const MenuItem = ({ children, onClick }: MenuItemProps) => {
  const classNames = [
    "m-0",
    "pt-2",
    "pb-2",
    "pl-4",
    "pr-4",
    "flex",
    "flex-row",
    "justify-start",
    "items-center",
    "flex-nowrap",
    "whitespace-nowrap",
    "hover:bg-gray-100",
  ];
  return (
    <div onClick={onClick} className={classNames.join(" ")}>
      {children}
    </div>
  );
};
