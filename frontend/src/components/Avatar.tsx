import type { CSSProperties } from "react";

type AvatarProps = {
  src?: string;
  children?: string;
  size?: number;
  sizeFit?: boolean;
  onClick?: () => void;
};

export const Avatar = ({
  src,
  children,
  onClick,
  size = 16,
  sizeFit = false,
}: AvatarProps) => {
  const cssProps = {
    "--avatar-width": `calc(var(--spacing) * ${size})`,
    "--avatar-height": `calc(var(--spacing) * ${size})`,
    "--avatar-text-size": `calc(var(--avatar-height) * 0.5)`,
  } as CSSProperties;
  const avatarImg = <img className="size-full" src={src} alt="" />;
  const fallbackClasses = [
    "text-(length:--avatar-text-size)",
    "font-bold",
    "select-none",
    "text-(--color-primary-contrast-text)",
  ];
  const avatarFallback = (
    <p className={fallbackClasses.join(" ")}>{children ?? ""}</p>
  );
  const sizeClasses = sizeFit
    ? ["h-full", "aspect-square"]
    : ["w-(--avatar-width)", "h-(--avatar-height)"];
  const containerClasses = [
    "bg-(--color-secondary-main)",
    "rounded-full",
    "overflow-hidden",
    "flex",
    "items-center",
    "justify-center",
    "p-0",
    "m-0",
  ];
  return (
    <div
      onClick={onClick}
      style={cssProps}
      className={containerClasses.concat(sizeClasses).join(" ")}
    >
      {src ? avatarImg : avatarFallback}
    </div>
  );
};
