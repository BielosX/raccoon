package internal

import (
	"bytes"
	"encoding/json"
	"errors"
	"fmt"
	"image/png"
	"net/http"
	"time"

	"image"

	"github.com/aws/aws-sdk-go-v2/aws"
	cognito "github.com/aws/aws-sdk-go-v2/service/cognitoidentityprovider"
	"github.com/aws/aws-sdk-go-v2/service/cognitoidentityprovider/types"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	s3types "github.com/aws/aws-sdk-go-v2/service/s3/types"
	"github.com/disintegration/imaging"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

type UsersRouter struct {
	logger            *zap.Logger
	router            *mux.Router
	s3Client          *s3.Client
	PresignClient     *s3.PresignClient
	cognitoClient     *cognito.Client
	userPoolId        string
	AvatarsBucketName string
}

func NewUsersRouter(conf *Config, logger *zap.Logger,
	rootRouter *mux.Router,
	awsCfg *aws.Config,
	validator *TokenValidator) *UsersRouter {
	router := rootRouter.PathPrefix("/users").Subrouter()
	router.Use(validator.ValidatingMiddleware)
	s3Client := s3.NewFromConfig(*awsCfg)
	presign := s3.NewPresignClient(s3Client)
	cognitoClient := cognito.NewFromConfig(*awsCfg)
	usersRouter := &UsersRouter{logger: logger,
		userPoolId:        conf.UserPoolId,
		s3Client:          s3Client,
		cognitoClient:     cognitoClient,
		PresignClient:     presign,
		AvatarsBucketName: conf.AvatarsBucketName,
		router:            router}
	usersRouter.registerRoutes()
	return usersRouter
}

func (u *UsersRouter) registerRoutes() {
	u.router.HandleFunc("/me/avatar", u.UploadAvatar).
		Methods("POST").
		HeadersRegexp("Content-Type", "image/.*")
	u.router.HandleFunc("/me/avatar", u.GetAvatar).Methods("GET")
}

const (
	AvatarLocationAttribute = "custom:avatar_location"
	CognitoUsernameClaim    = "username"
	MaxAvatarSize           = 1024 * 1024 * 5
)

type AvatarResponse struct {
	Url string `json:"url"`
}

func (u *UsersRouter) getUserId(r *http.Request) (string, error) {
	token := GetParsedToken(r)
	if token == nil {
		return "", errors.New("unable to fetch token from the request context")
	}
	if claims, ok := token.Claims.(jwt.MapClaims); ok {
		return claims[CognitoUsernameClaim].(string), nil
	}
	return "", errors.New("unable to fetch claims from token")
}

func (u *UsersRouter) GetAvatar(w http.ResponseWriter, r *http.Request) {
	userId, err := u.getUserId(r)
	if err != nil {
		u.logger.Error("unable to fetch user id", zap.Error(err))
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	user, err := u.cognitoClient.AdminGetUser(r.Context(), &cognito.AdminGetUserInput{
		UserPoolId: &u.userPoolId,
		Username:   &userId,
	})
	if err != nil {
		u.logger.Warn("Failed to get user", zap.Error(err))
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	attributes := ToUserAttributesMap(user.UserAttributes)
	location, ok := attributes[AvatarLocationAttribute]
	if !ok {
		w.WriteHeader(http.StatusNotFound)
		return
	}
	result, err := u.PresignClient.PresignGetObject(r.Context(), &s3.GetObjectInput{
		Bucket: &u.AvatarsBucketName,
		Key:    &location,
	}, s3.WithPresignExpires(time.Minute*2))
	if err != nil {
		var noSuchKey *s3types.NoSuchKey
		if errors.As(err, &noSuchKey) {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	response := &AvatarResponse{
		Url: result.URL,
	}
	value, err := json.Marshal(response)
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	w.Header().Set(HeaderContentType, ContentTypeJSON)
	_, _ = w.Write(value)
}

func (u *UsersRouter) UploadAvatar(w http.ResponseWriter, r *http.Request) {
	userId, err := u.getUserId(r)
	if err != nil {
		u.logger.Error("unable to fetch user id", zap.Error(err))
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	avatarId := uuid.New().String()
	reader := http.MaxBytesReader(w, r.Body, MaxAvatarSize)
	defer ignore(reader.Close)
	img, _, err := image.Decode(reader)
	if err != nil {
		var maxErr *http.MaxBytesError
		if errors.As(err, &maxErr) {
			w.WriteHeader(http.StatusRequestEntityTooLarge)
			return
		}
		u.logger.Error("failed to decode image", zap.Error(err))
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	avatarFileName := fmt.Sprintf("%s.png", avatarId)
	resized := imaging.Resize(img, 512, 512, imaging.Lanczos)
	var buf bytes.Buffer
	err = png.Encode(&buf, resized)
	if err != nil {
		u.logger.Error("error encoding resized image", zap.Error(err))
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	_, err = u.s3Client.PutObject(r.Context(), &s3.PutObjectInput{
		Bucket: &u.AvatarsBucketName,
		Key:    &avatarFileName,
		Body:   &buf,
	})
	if err != nil {
		u.logger.Error("failed to upload avatar", zap.Error(err))
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	_, err = u.cognitoClient.AdminUpdateUserAttributes(
		r.Context(),
		&cognito.AdminUpdateUserAttributesInput{
			UserPoolId: &u.userPoolId,
			Username:   &userId,
			UserAttributes: []types.AttributeType{
				{
					Name:  aws.String(AvatarLocationAttribute),
					Value: &avatarFileName,
				},
			},
		},
	)
	if err != nil {
		u.logger.Error("error updating avatar location custom attribute", zap.Error(err))
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
}
