import { Typography } from "@mui/material";
import { useCognito } from "../CognitoProvider.tsx";
import { useEffect, useState } from "react";

export const UserInfo = () => {
  const { getUserInfo } = useCognito();
  const [userName, setUserName] = useState("");

  useEffect(() => {
    getUserInfo().then((info) => {
      setUserName(info.name as string);
    });
  }, [getUserInfo]);

  return <Typography>{userName}</Typography>;
};
