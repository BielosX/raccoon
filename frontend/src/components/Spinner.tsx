import type { CSSProperties } from "react";

type SpinnerProps = {
  size?: number;
};

export const Spinner = ({ size = 8 }: SpinnerProps) => {
  const cssProps = {
    "--spinner-width": `calc(var(--spacing) * ${size})`,
    "--spinner-height": `calc(var(--spacing) * ${size})`,
  } as CSSProperties;
  return (
    <div
      style={cssProps}
      className="relative w-(--spinner-width) h-(--spinner-height)"
    >
      <div className="absolute inset-0 rounded-full border-4 border-(--color-primary-main) opacity-25"></div>
      <div className="absolute inset-0 rounded-full border-4 border-(--color-primary-main) border-t-transparent animate-spin"></div>
    </div>
  );
};
