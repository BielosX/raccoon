import { AppBar, Box, Button } from "@mui/material";
import { useCognito } from "../CognitoProvider.tsx";
import { UserInfo } from "../components/UserInfo.tsx";

export const MainPage = () => {
  const { isAuthenticated, loginWithRedirect } = useCognito();

  return (
    <Box>
      <AppBar position="static">
        {!isAuthenticated && (
          <Button
            color="inherit"
            onClick={() => loginWithRedirect({ returnTo: "/" })}
          >
            Login
          </Button>
        )}
        {isAuthenticated && <UserInfo />}
      </AppBar>
    </Box>
  );
};
