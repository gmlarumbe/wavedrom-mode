[![MELPA](https://melpa.org/packages/wavedrom-mode-badge.svg)](https://melpa.org/#/wavedrom-mode)
[![Build Status](https://github.com/gmlarumbe/wavedrom-mode/workflows/elisp-check/badge.svg)](https://github.com/gmlarumbe/wavedrom-mode/actions/workflows/elisp-check.yml)
[![License: GPL v3](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
<!-- [![MELPA Stable](https://stable.melpa.org/packages/wavedrom-mode-badge.svg)](https://stable.melpa.org/#/wavedrom-mode) -->

# wavedrom.el - Wavedrom Integration for Emacs #

This package provides a major mode for editing and rendering [WaveJSON](https://github.com/wavedrom/schema/blob/master/WaveJSON.md)
files to create timing diagrams using [wavedrom](https://wavedrom.com/).

## Demo

<img src="https://github.com/gmlarumbe/wavedrom-mode/assets/51021955/f2750631-eb69-4fa2-a11b-c127092776c6" height=500>

## Requirements ##

- `wavedrom-cli`: https://github.com/wavedrom/cli

- Optional: `inkscape` to export to PDF


## Installation ##

### MELPA ###

`wavedrom` is available on MELPA.

### straight.el ###

To install it via [straight](https://github.com/radian-software/straight.el) with `use-package`:

```emacs-lisp
(straight-use-package 'use-package)
(use-package wavedrom)
```


## Basic config ##

The package comes with sensible default values.  However, you can
tweak it either with `M-x customize-group RET wavedrom RET` or with
the following Elisp code:

```emacs-lisp
(setq wavedrom-output-format "pdf")
(setq wavedrom-output-directory "~/wavedrom")
;; Faces suitable for dark themes
(set-face-attribute 'wavedrom-font-lock-brackets-face nil :foreground "goldenrod")
(set-face-attribute 'wavedrom-font-lock-punctuation-face nil :foreground "burlywood")
```

## Usage ##

- Create a file with `.wjson` extension and `wavedrom-mode` will automatically
  be enabled next time it is opened.

- Fill the file with valid [WaveJSON](https://github.com/wavedrom/schema/blob/master/WaveJSON.md)
  syntax and every time it is saved the function `wavedrom-compile`
  will be executed, updating the output file and its associated buffer.
  This provides a WYSIWYG-like result similar to the one with the web editor.

- The output file path will be determined from the value of customizable
  variables `wavedrom-output-format` and `wavedrom-output-directory`.
  For example, if editing the file `hello_world.wjson`:
  ```elisp
  (setq wavedrom-output-format "svg")
  (setq wavedrom-output-directory "~/wavedrom")
  ```
  The rendered file will be created at: `~/wavedrom/hello_world.svg`


## Keybindings

- <kbd>C-c C-c</kbd>: `wavedrom-compile`
- <kbd>C-c C-p</kbd>: `wavedrom-preview-browser`


## Other packages

* [verilog-ext](https://github.com/gmlarumbe/verilog-ext): SystemVerilog Extensions for Emacs
  * Package to edit SystemVerilog sources
* [vhdl-ext](https://github.com/gmlarumbe/vhdl-ext): VHDL Extensions for Emacs
  * Package to edit VHDL sources
* [fpga](https://github.com/gmlarumbe/fpga): FPGA & ASIC Utilities for Emacs
  * Utilities for tools of major vendors of FPGA & ASIC
* [vunit-mode](https://github.com/embed-me/vunit-mode.git): VUnit Mode for Emacs
  * Integration of [VUnit](https://github.com/VUnit/vunit) workflow.

