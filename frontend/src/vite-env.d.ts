interface ImportMetaEnv {
  readonly VITE_BUILD_TIMESTAMP: string | undefined
  readonly VITE_COGNITO_DOMAIN_URL: string
  readonly VITE_COGNITO_CLIENT_ID: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}