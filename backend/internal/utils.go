package internal

import (
	"net/http"

	"github.com/aws/aws-sdk-go-v2/aws"
	cognitoTypes "github.com/aws/aws-sdk-go-v2/service/cognitoidentityprovider/types"
)

func ignore(f func() error) {
	_ = f()
}

func WriteString(w http.ResponseWriter, s string, code int) {
	w.WriteHeader(code)
	_, _ = w.Write([]byte(s))
}

func ToUserAttributesMap(attributes []cognitoTypes.AttributeType) map[string]string {
	result := make(map[string]string)
	for _, attribute := range attributes {
		if attribute.Value == nil {
			continue
		}
		result[aws.ToString(attribute.Name)] = aws.ToString(attribute.Value)
	}
	return result
}
