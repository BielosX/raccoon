import type {CSSProperties} from "react";

type AvatarProps = {
  src?: string;
  children?: string;
  size?: number;
  onClick?: () => void;
}

export const Avatar = ({src, children, onClick, size = 16}: AvatarProps) => {
  const cssProps = {
    '--avatar-width': `calc(var(--spacing) * ${size})`,
    '--avatar-height': `calc(var(--spacing) * ${size})`,
    '--avatar-text-size': `calc(var(--avatar-height) * 0.5)`,
  } as CSSProperties;
  const avatarImg = <img className="size-full" src={src} alt=""/>
  const fallbackClasses = [
    "text-(length:--avatar-text-size)",
    "font-bold",
    "text-(--color-primary-contrast-text)"
  ];
  const avatarFallback = <p className={fallbackClasses.join(" ")}>{children ?? ""}</p>
  const containerClasses = [
    "w-(--avatar-width)",
    "h-(--avatar-height)",
    "bg-(--color-secondary-main)",
    "rounded-full",
    "overflow-hidden",
    "flex",
    "items-center",
    "justify-center",
    "p-0",
    "m-0"
  ]
  return (
    <div onClick={onClick} style={cssProps} className={containerClasses.join(' ')}>
      {src ? avatarImg : avatarFallback}
    </div>
  );
}