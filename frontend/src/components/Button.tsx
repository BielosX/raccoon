import type {ReactNode} from "react";

type ButtonProps = {
  onClick?: () => void;
  children: ReactNode;
}

export const Button = ({children, onClick}: ButtonProps) => {
  const classNames = [
    "bg-(--color-primary-main)",
    "text-(--color-primary-contrast-text)",
    "px-4",
    "py-2",
    "rounded",
    "hover:bg-(--color-primary-dark)",
    "shadow-(color:--color-shadow-primary)",
    "hover:shadow-sm",
    "transition-colors",
    "transition-shadow",
    "duration-300",
  ];
  return (
    <button onClick={onClick} className={classNames.join(" ")}>
      {children}
    </button>
  )
}