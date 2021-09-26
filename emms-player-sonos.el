;;; emms-player-sonos.el --- Sonos support for EMMS -*- lexical-binding: t; -*-

;; Author: Alex Griffin <https://github.com/ajgrf>
;; Maintainer: Alex Griffin <a@ajgrf.com>
;; Version: 0.1.0
;; Homepage: https://github.com/ajgrf/emms-player-sonos
;; Package-Requires: ((emacs "24.3"))

;; This file is not part of GNU Emacs.

;; Copyright © 2021 Alex Griffin <a@ajgrf.com>
;;
;;
;; Permission to use, copy, modify, and/or distribute this software for
;; any purpose with or without fee is hereby granted, provided that the
;; above copyright notice and this permission notice appear in all
;; copies.
;;
;; THE SOFTWARE IS PROVIDED "AS IS" AND ISC DISCLAIMS ALL WARRANTIES WITH
;; REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
;; MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL ISC BE LIABLE FOR ANY
;; SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
;; WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
;; ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT
;; OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

;;; Commentary:

;;  EMMS player for playing local files through networked Sonos speakers.
;;  Uses the soco-cli utility. There is a significant delay between starting
;;  a track and actual audio playback (~25 seconds for me), which kinda limits
;;  the usefulness of this. Still neat, though.

;; Add the following to your `emms-player-list':

;; emms-player-sonos

;;; Code:

(require 'emms)
(require 'emms-player-simple)

(defgroup emms-player-sonos nil
  "EMMS player for sonos."
  :group 'emms-player
  :prefix "emms-player-sonos-")

(defcustom emms-player-sonos-command-name "sonos"
  "The command name of sonos."
  :type 'file)

(defcustom emms-player-sonos-speaker "_all_"
  "Name or IP address of the Sonos speaker to play through."
  :type 'string)

(defcustom emms-player-sonos-parameters
  '("--use-local-speaker-list" "--no-env")
  "The arguments to `emms-player-sonos-command-name'."
  :type '(repeat string))

(defcustom emms-player-sonos
  (emms-player
   #'emms-player-sonos-start
   #'emms-player-sonos-stop
   #'emms-player-sonos-playable-p)
  "*Parameters for sonos player."
  :type '(cons symbol alist))

(emms-player-set emms-player-sonos 'regex
                 (emms-player-simple-regexp "mp3" "m4a" "mp4" "flac" "ogg" "wma" "wav" "aif"))

(emms-player-set emms-player-sonos 'pause #'emms-player-sonos-pause)
(emms-player-set emms-player-sonos 'resume #'emms-player-sonos-resume)

;; Global variables
(defvar emms-player-sonos-process-name "emms-player-sonos-process"
  "The name of the sonos player process")

(defun emms-player-sonos-run (&rest args)
  "Run sonos command with the given ARGS, adding the configured parameters and speaker."
  (apply #'start-process
         emms-player-sonos-process-name
         nil
         emms-player-sonos-command-name
         (append emms-player-sonos-parameters
                 (list emms-player-sonos-speaker)
                 args)))

(defun emms-player-sonos-start (track)
  "Start the player process with the given TRACK."
  (let* ((filename (emms-track-name track))
         (process (emms-player-sonos-run "play_file" filename)))
    ;; add a sentinel for signaling termination
    (set-process-sentinel process #'emms-player-simple-sentinel))
  (emms-player-started emms-player-sonos))

(defun emms-player-sonos-stop ()
  "Stop the player process."
  (let ((process (get-process emms-player-sonos-process-name)))
    (when process
      (kill-process process)
      (delete-process process)
      (emms-player-sonos-run "stop"))))

(defun emms-player-sonos-pause ()
  "Pause the Sonos player."
  (emms-player-sonos-run "pause"))

(defun emms-player-sonos-resume ()
  "Resume the Sonos player."
  (emms-player-sonos-run "play"))

(defun emms-player-sonos-playable-p (track)
  "Return non-nil when we can play this TRACK."
  (and (executable-find emms-player-sonos-command-name)
       (memq (emms-track-type track)
             '(file))
       (string-match (emms-player-get emms-player-sonos 'regex)
                     (emms-track-name track))))

(provide 'emms-player-sonos)
;;; emms-player-sonos.el ends here
