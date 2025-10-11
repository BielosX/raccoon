import {Box, Typography} from "@mui/material";

export const VersionPage = () => {
  const version: string | undefined = import.meta.env.VITE_BUILD_VERSION;
  const timestamp: number | undefined = import.meta.env.VITE_BUILD_TIMESTAMP;
  const versionString = `Version: ${version}`;
  const buildTime = new Date(timestamp ?? 0);
  const buildTimeString = `Build time: ${buildTime.toISOString()}`;
  return (
    <Box>
      <Typography>{versionString}</Typography>
      <Typography>{buildTimeString}</Typography>
    </Box>
  );
};