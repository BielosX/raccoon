import { Button } from "./Button";
import { Avatar } from "./Avatar";
import { useCognito } from "../CognitoProvider.tsx";
import { useEffect, useState } from "react";
import { ClickAwayListener } from "./ClickAwayListener";
import { Menu, MenuItem } from "./Menu";
import { useAvatar } from "../AvatarProvider.tsx";

const AnonymousMenu = () => {
  const { loginWithRedirect } = useCognito();
  return (
    <div className="flex flex-row items-center justify-center">
      <Button>Sign Up</Button>
      <Button onClick={() => loginWithRedirect()}>Sign in</Button>
    </div>
  );
};

const AuthenticatedMenu = () => {
  const [avatarUrl, setAvatarUrl] = useState<string | undefined>();
  const [userName, setUserName] = useState<string | null>(null);
  const [menuOpen, setMenuOpen] = useState(false);
  const { getUserInfo, logout } = useCognito();
  const { getAvatar } = useAvatar();

  useEffect(() => {
    let url: string | null = null;

    const setupMenu = async () => {
      const [avatar, info] = await Promise.all([getAvatar(), getUserInfo()]);
      if (avatar) {
        url = URL.createObjectURL(avatar);
        setAvatarUrl(url);
      } else {
        setUserName(info.username ?? info.name ?? "");
      }
    };

    setupMenu().catch((error) => console.log(error));

    return () => {
      if (url) {
        URL.revokeObjectURL(url);
      }
    };
  }, []);

  return (
    <ClickAwayListener onClickAway={() => setMenuOpen(false)}>
      <div className="flex flex-col items-center justify-center">
        <Avatar size={8} onClick={() => setMenuOpen(true)} src={avatarUrl}>
          {userName?.charAt(0).toUpperCase()}
        </Avatar>
        {menuOpen && (
          <Menu>
            <MenuItem>Profile</MenuItem>
            <MenuItem onClick={() => logout()}>Sign Out</MenuItem>
          </Menu>
        )}
      </div>
    </ClickAwayListener>
  );
};

export const TopBar = () => {
  const { isAuthenticated } = useCognito();

  return (
    <div className="fixed w-full h-14 bg-(--color-primary-main) flex flex-row items-center justify-between p-2">
      <p className="text-xl font-bold text-(--color-primary-contrast-text)">
        Awesome Chat
      </p>
      {isAuthenticated ? <AuthenticatedMenu /> : <AnonymousMenu />}
    </div>
  );
};
