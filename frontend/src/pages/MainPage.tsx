export const MainPage = () => {
  const buildTime = new Date(import.meta.env.VITE_BUILD_TIMESTAMP ?? 0);
  const buildTimeString = `Build time: ${buildTime.toISOString()}`;
  return <div>{buildTimeString}</div>;
};
