package types

import (
	"strings"
	"time"
)

type ZephyrDate struct {
	time.Time
}

func (date *ZephyrDate) UnmarshalJSON(b []byte) error {
	s := strings.Trim(string(b), "\"")
	if s == "" {
		return nil
	}

	var err error
	date.Time, err = time.Parse("Monday, 2006/01/02", s)
	if err != nil {
		return err
	}

	return nil
}

func (date *ZephyrDate) MarshalJSON() ([]byte, error) {
	if date.Time.IsZero() {
		return []byte("\"\""), nil
	}

	fmtDate := date.Time.Format("Monday, 2006/01/02")

	return []byte("\"" + fmtDate + "\""), nil
}
