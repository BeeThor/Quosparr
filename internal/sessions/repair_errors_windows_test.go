//go:build windows

package sessions

import (
	"os"
	"path/filepath"
	"testing"

	"golang.org/x/sys/windows"
)

func TestRepairRefusesWindowsACLUnreadableSessionTree(t *testing.T) {
	for _, folder := range []string{"sessions", "archived_sessions/nested"} {
		t.Run(folder, func(t *testing.T) {
			home := t.TempDir()
			dir := filepath.Join(home, folder)
			if err := os.MkdirAll(dir, 0700); err != nil {
				t.Fatal(err)
			}
			denyDirectoryListing(t, dir)
			if _, err := os.ReadDir(dir); !os.IsPermission(err) {
				t.Fatalf("ACL must deny enumeration: %v", err)
			}
			assertRepairFailsWithoutWriting(t, home)
		})
	}
}

func denyDirectoryListing(t *testing.T, dir string) {
	t.Helper()
	saved, err := windows.GetNamedSecurityInfo(dir, windows.SE_FILE_OBJECT, windows.DACL_SECURITY_INFORMATION)
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() {
		acl, _, err := saved.DACL()
		if err == nil {
			err = windows.SetNamedSecurityInfo(dir, windows.SE_FILE_OBJECT, windows.DACL_SECURITY_INFORMATION|windows.PROTECTED_DACL_SECURITY_INFORMATION, nil, nil, acl, nil)
		}
		if err != nil {
			t.Error(err)
		}
	})
	user, err := windows.GetCurrentProcessToken().GetTokenUser()
	if err != nil {
		t.Fatal(err)
	}
	sid := user.User.Sid.String()
	sd, err := windows.SecurityDescriptorFromString("D:P(D;;0x1;;;" + sid + ")(A;;FA;;;" + sid + ")")
	if err != nil {
		t.Fatal(err)
	}
	acl, _, err := sd.DACL()
	if err != nil {
		t.Fatal(err)
	}
	if err := windows.SetNamedSecurityInfo(dir, windows.SE_FILE_OBJECT, windows.DACL_SECURITY_INFORMATION|windows.PROTECTED_DACL_SECURITY_INFORMATION, nil, nil, acl, nil); err != nil {
		t.Fatal(err)
	}
}
