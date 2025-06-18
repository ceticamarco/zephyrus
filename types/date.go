package types

import (
	"strings"
	"time"
)

type ZephyrDate struct {
	Date time.Time
}

func (date *ZephyrDate) UnmarshalJSON(b []byte) error {
	s := strings.Trim(string(b), "\"")
	if s == "" {
		return nil
	}

	var err error
	date.Date, err = time.Parse("Monday, 2006/01/02", s)
	if err != nil {
		return err
	}

	return nil
}

func (date ZephyrDate) MarshalJSON() ([]byte, error) {
	if date.Date.IsZero() {
		return []byte("\"\""), nil
	}

	fmtDate := date.Date.Format("Monday, 2006/01/02")

	return []byte("\"" + fmtDate + "\""), nil
}
