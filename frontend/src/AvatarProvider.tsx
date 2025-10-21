import { type ReactNode, useContext, useState } from "react";
import { createContext } from "react";
import { useCognito } from "./CognitoProvider.tsx";

type AvatarContextType = {
  getAvatar: () => Promise<Blob | null>;
  uploadAvatar: (avatar: Blob) => Promise<void>;
};

type GetAvatarResponse = {
  url: string;
};

const AvatarContext = createContext<AvatarContextType>({
  getAvatar: () => Promise.resolve(new Blob()),
  uploadAvatar: (_: Blob) => Promise.resolve(),
});

export const AvatarProvider = ({ children }: { children: ReactNode }) => {
  const [avatar, setAvatar] = useState<Blob | null>(null);
  const { getAccessToken } = useCognito();

  const getAvatar = async () => {
    if (avatar) {
      return avatar;
    }
    const token = await getAccessToken();
    const response = await fetch("/api/users/me/avatar", {
      method: "GET",
      headers: {
        Authorization: `Bearer ${token}`,
      },
    });
    if (!response.ok) {
      return null;
    }
    const result: GetAvatarResponse = await response.json();
    const avatarResponse = await fetch(result.url, {
      method: "GET",
    });
    const blob = await avatarResponse.blob();
    setAvatar(blob);
    return blob;
  };

  const uploadAvatar = async (_: Blob) => {
    return Promise.resolve();
  };

  return (
    <AvatarContext
      value={{
        getAvatar,
        uploadAvatar,
      }}
    >
      {children}
    </AvatarContext>
  );
};

export const useAvatar = () => {
  const context = useContext(AvatarContext);
  if (!context) {
    throw new Error("useAvatar must be used within a AvatarProvider");
  }
  return context;
};
