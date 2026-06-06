# Rendering demo

A sandbox page that exercises the Material/pymdownx features the
[style guide](https://github.com/Fax-Me-In-The-Cloud/homelab-pages/blob/main/STYLE.md)
relies on, so their rendering can be checked on the live GitHub Pages site.
Safe to delete once verified.

## Admonitions

!!! note "Note"
    Four-space-indented body, rendered as a callout box.

!!! warning "Warning"
    Use for gotchas and destructive steps.

!!! tip "Tip"
    Handy aside that isn't critical.

## Collapsible details

??? info "Click to expand"
    Hidden until the reader clicks (`???` collapsed, `???+` expanded).

## Tabbed content

=== "macOS"
    Tab one body (requires `pymdownx.tabbed`).

=== "Linux"
    Tab two body.

## Code block — title and highlight

```yaml title="example.yaml" hl_lines="2"
key: value
highlighted: this line
other: untouched
```

## Single-line command

```bash
kubectl get pods -n home-assistant -o wide
```

## Including a file (pymdownx.snippets)

The block below embeds the **live content** of `docs/home_assistant/matter_server.yaml`
via a snippet — edit that file and this updates automatically.

```yaml title="matter_server.yaml"
--8<-- "home_assistant/matter_server.yaml"
```

## Referencing a file

Link to the raw sibling file instead of embedding it:
[matter_server.yaml](home_assistant/matter_server.yaml).

## Table

| Node | IP | Role |
|---|---|---|
| `rpi01` | `192.168.1.11` | control-plane |
| `rpi02` | `192.168.1.12` | control-plane |
| `rpi03` | `192.168.1.13` | control-plane |
