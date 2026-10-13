package sqliteruntime

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"log"
	"os"
	"path/filepath"

	"github.com/licoy/quosparr/internal/platform"
)

// Each version has an immutable, hash-named directory, so an update never
// replaces a DLL that another process still has loaded. A concurrent first
// extraction can win publication; only an identical, private file is accepted.
func prepareLibrary(root string, data []byte, expected string) (string, error) {
	sum := sha256.Sum256(data)
	if hex.EncodeToString(sum[:]) != expected || len(data) == 0 {
		return "", errors.New("sqlite runtime: embedded library checksum mismatch")
	}
	if !filepath.IsAbs(root) {
		return "", errors.New("sqlite runtime: data directory must be absolute")
	}
	for _, name := range []string{"", "runtime", "sqlite", expected} {
		root = filepath.Join(root, name)
		if err := privateDirectory(root); err != nil {
			return "", fmt.Errorf("sqlite runtime directory: %w", err)
		}
	}
	path := filepath.Join(root, "mygo-sqlite3.dll")
	if _, err := os.Lstat(path); errors.Is(err, os.ErrNotExist) {
		if err := platform.WriteFileAtomic(path, data, 0o600); err != nil {
			if verifyErr := verifyLibrary(path, data); verifyErr != nil {
				return "", fmt.Errorf("sqlite runtime extraction: %w", errors.Join(err, verifyErr))
			}
			log.Printf("sqlite runtime: reused identical library published during extraction: %v", err)
		}
	} else if err != nil {
		return "", err
	}
	if err := verifyLibrary(path, data); err != nil {
		return "", err
	}
	return path, nil
}

func privateDirectory(path string) error {
	info, err := os.Lstat(path)
	if err == nil && (!info.IsDir() || info.Mode()&os.ModeSymlink != 0) {
		return errors.New("expected a directory, not a file or symbolic link")
	}
	if err != nil && !errors.Is(err, os.ErrNotExist) {
		return err
	}
	return platform.EnsurePrivateDirectory(path)
}

func verifyLibrary(path string, expected []byte) error {
	info, err := os.Lstat(path)
	if err != nil {
		return err
	}
	if !info.Mode().IsRegular() {
		return errors.New("sqlite runtime: cached library is not a regular file")
	}
	if err := platform.VerifyOwnerOnly(path, 0o600); err != nil {
		return fmt.Errorf("sqlite runtime permissions: %w", err)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	if !bytes.Equal(data, expected) {
		return errors.New("sqlite runtime: cached library checksum mismatch")
	}
	return nil
}
