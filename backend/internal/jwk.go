package internal

import (
	"crypto/rsa"
	"encoding/base64"
	"encoding/binary"
	"math/big"
)

type JWK struct {
	Kid string `json:"kid"`
	N   string `json:"n"`
	E   string `json:"e"`
	Alg string `json:"alg"`
	Use string `json:"use"`
	Kty string `json:"kty"`
}

type JWKS struct {
	Keys []JWK `json:"keys"`
}

func (j *JWKS) ToRSAMap() (map[string]*rsa.PublicKey, error) {
	m := make(map[string]*rsa.PublicKey, len(j.Keys))
	for _, key := range j.Keys {
		if key.Alg == "RS256" && key.Kty == "RSA" {
			nBytes, err := base64.RawURLEncoding.DecodeString(key.N)
			if err != nil {
				return nil, err
			}
			eBytes, err := base64.RawURLEncoding.DecodeString(key.E)
			if err != nil {
				return nil, err
			}
			nBig := new(big.Int).SetBytes(nBytes)
			var leftPadEBytes [4]byte
			copy(leftPadEBytes[4-len(eBytes):], eBytes)
			m[key.Kid] = &rsa.PublicKey{
				N: nBig,
				E: int(binary.BigEndian.Uint32(leftPadEBytes[:])),
			}
		}
	}
	return m, nil
}
