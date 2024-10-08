/*
Copyright © 2024 Marçal Pla <marcal@taleia.software>
*/
package utils

import (
	"crypto/rand"
	"encoding/base64"
	"strings"
)

func ReplacePlaceholder(body string, placeholder string, replacement string) string {
	placeholderIndex := strings.Index(body, placeholder)
	if placeholderIndex == -1 {
		return body
	}
	placeholderIndexRunes := len([]rune(body[:placeholderIndex]))
	bodyRunes := []rune(body)
	identation := 0
	for i := placeholderIndexRunes - 1; i >= 0; i-- {
		if bodyRunes[i] == '\n' {
			break
		}
		identation++
	}
	identationText := " "
	replacement = strings.ReplaceAll(replacement, "\n", "\n"+strings.Repeat(identationText, identation))
	return strings.ReplaceAll(body, placeholder, replacement)
}

func GenerateRandomBase64String(length int) (string, error) {
	randomBytes := make([]byte, length)
	_, err := rand.Read(randomBytes)
	if err != nil {
		return "", err
	}
	return base64.StdEncoding.EncodeToString(randomBytes), nil
}
