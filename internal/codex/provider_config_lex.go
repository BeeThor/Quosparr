package codex

import (
	"errors"
	"strconv"
)

// A deliberately small TOML statement lexer. It does not interpret values; it
// only finds where each statement starts and ends (honouring strings, comments
// and multi-line arrays or strings) so provider_config.go can edit whole
// statements while leaving every other byte alone. Input is always validated
// by a real TOML parser first and after, so a lexer slip fails closed.

type tomlKind int

const (
	tomlBlank tomlKind = iota
	tomlComment
	tomlKeyVal
	tomlHeader
)

type tomlItem struct {
	start, end int // byte range, end includes the line terminator
	kind       tomlKind
	path       []string // key path of a key/value, or table path of a header
	array      bool     // [[header]]
	mlString   bool     // contains a multi-line string
}

var errTOMLLex = errors.New("codex: config.toml uses syntax that cannot be edited safely")

func lexTOML(data []byte) ([]tomlItem, error) {
	var items []tomlItem
	pos := 0
	for pos < len(data) {
		item, err := lexStatement(data, pos)
		if err != nil {
			return nil, err
		}
		items = append(items, item)
		pos = item.end
	}
	return items, nil
}

func lexStatement(data []byte, start int) (tomlItem, error) {
	p := skipBlanks(data, start)
	item := tomlItem{start: start}
	switch {
	case p >= len(data) || data[p] == '\n' || (data[p] == '\r' && p+1 < len(data) && data[p+1] == '\n'):
		item.kind = tomlBlank
		item.end = lineEnd(data, p)
	case data[p] == '#':
		item.kind = tomlComment
		item.end = lineEnd(data, p)
	case data[p] == '[':
		return lexHeader(data, start, p)
	default:
		return lexKeyVal(data, start, p)
	}
	return item, nil
}

func lexHeader(data []byte, start, p int) (tomlItem, error) {
	item := tomlItem{start: start, kind: tomlHeader}
	p++
	if p < len(data) && data[p] == '[' {
		item.array = true
		p++
	}
	path, p, err := lexKey(data, p)
	if err != nil {
		return item, err
	}
	p = skipBlanks(data, p)
	closers := 1
	if item.array {
		closers = 2
	}
	for i := 0; i < closers; i++ {
		if p >= len(data) || data[p] != ']' {
			return item, errTOMLLex
		}
		p++
	}
	p = skipBlanks(data, p)
	if p < len(data) && data[p] != '#' && data[p] != '\n' && data[p] != '\r' {
		return item, errTOMLLex
	}
	item.path = path
	item.end = lineEnd(data, p)
	return item, nil
}

func lexKeyVal(data []byte, start, p int) (tomlItem, error) {
	item := tomlItem{start: start, kind: tomlKeyVal}
	path, p, err := lexKey(data, p)
	if err != nil {
		return item, err
	}
	p = skipBlanks(data, p)
	if p >= len(data) || data[p] != '=' {
		return item, errTOMLLex
	}
	end, ml, err := scanValue(data, p+1)
	if err != nil {
		return item, err
	}
	item.path, item.end, item.mlString = path, end, ml
	return item, nil
}

// lexKey reads a dotted key (bare, "basic" or 'literal' parts) and returns
// the parts and the position after the key.
func lexKey(data []byte, p int) ([]string, int, error) {
	var parts []string
	for {
		p = skipBlanks(data, p)
		part, next, err := lexKeyPart(data, p)
		if err != nil {
			return nil, p, err
		}
		parts = append(parts, part)
		p = skipBlanks(data, next)
		if p < len(data) && data[p] == '.' {
			p++
			continue
		}
		return parts, p, nil
	}
}

func lexKeyPart(data []byte, p int) (string, int, error) {
	if p >= len(data) {
		return "", p, errTOMLLex
	}
	switch c := data[p]; {
	case c == '"':
		for i := p + 1; i < len(data) && data[i] != '\n'; i++ {
			if data[i] == '\\' {
				i++
			} else if data[i] == '"' {
				raw := string(data[p : i+1])
				if s, err := strconv.Unquote(raw); err == nil {
					return s, i + 1, nil
				}
				return raw, i + 1, nil
			}
		}
		return "", p, errTOMLLex
	case c == '\'':
		for i := p + 1; i < len(data) && data[i] != '\n'; i++ {
			if data[i] == '\'' {
				return string(data[p+1 : i]), i + 1, nil
			}
		}
		return "", p, errTOMLLex
	}
	i := p
	for i < len(data) && isBareKeyByte(data[i]) {
		i++
	}
	if i == p {
		return "", p, errTOMLLex
	}
	return string(data[p:i]), i, nil
}

func isBareKeyByte(c byte) bool {
	return c >= 'a' && c <= 'z' || c >= 'A' && c <= 'Z' || c >= '0' && c <= '9' || c == '_' || c == '-'
}

// scanValue finds the end (after the terminating newline) of the value that
// starts at p. Newlines inside strings, arrays and inline tables do not end it.
func scanValue(data []byte, p int) (end int, mlString bool, err error) {
	depth := 0
	for i := p; i < len(data); i++ {
		switch data[i] {
		case '"', '\'':
			next, ml, serr := skipString(data, i)
			if serr != nil {
				return 0, false, serr
			}
			mlString = mlString || ml
			i = next - 1
		case '#':
			for i < len(data) && data[i] != '\n' {
				i++
			}
			if depth == 0 {
				return min(i+1, len(data)), mlString, nil
			}
		case '[', '{':
			depth++
		case ']', '}':
			depth--
		case '\n':
			if depth <= 0 {
				return i + 1, mlString, nil
			}
		}
	}
	if depth > 0 {
		return 0, false, errTOMLLex
	}
	return len(data), mlString, nil
}

// skipString returns the position after the string literal opening at p.
func skipString(data []byte, p int) (next int, multiline bool, err error) {
	quote := data[p]
	if p+2 < len(data) && data[p+1] == quote && data[p+2] == quote {
		for i := p + 3; i < len(data); i++ {
			switch {
			case quote == '"' && data[i] == '\\':
				i++
			case data[i] == quote:
				n := 1
				for i+n < len(data) && data[i+n] == quote {
					n++
				}
				if n >= 3 {
					return i + n, true, nil
				}
				i += n - 1
			}
		}
		return 0, true, errTOMLLex
	}
	for i := p + 1; i < len(data) && data[i] != '\n'; i++ {
		switch {
		case quote == '"' && data[i] == '\\':
			i++
		case data[i] == quote:
			return i + 1, false, nil
		}
	}
	return 0, false, errTOMLLex
}

func skipBlanks(data []byte, p int) int {
	for p < len(data) && (data[p] == ' ' || data[p] == '\t') {
		p++
	}
	return p
}

// lineEnd returns the position after the next newline at or after p.
func lineEnd(data []byte, p int) int {
	for p < len(data) && data[p] != '\n' {
		p++
	}
	return min(p+1, len(data))
}
