;;; emms-player-sonos.el --- Sonos support for EMMS -*- lexical-binding: t; -*-

;; Author: Alex Griffin <https://github.com/ajgrf>
;; Maintainer: Alex Griffin <a@ajgrf.com>
;; Version: 0.1.0
;; Homepage: https://github.com/ajgrf/emms-player-sonos
;; Package-Requires: ((emacs "25.1"))

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
;;
;; emms-player-sonos

;; To change the volume on your Sonos speakers, do the following:
;;
;;   (setq emms-volume-change-function #'emms-volume-sonos-change)

;;; Code:

(require 'emms)
(require 'emms-player-simple)
(require 'subr-x)

(defgroup emms-player-sonos nil
  "EMMS player for sonos."
  :group 'emms-player
  :prefix "emms-player-sonos-")

(defcustom emms-player-sonos-command-name "sonos"
  "The command name of sonos."
  :type 'file)

(defcustom emms-player-sonos-speaker (or (getenv "SPKR") "_all_")
  "Name or IP address of the Sonos speaker to play through."
  :type 'string)

(defcustom emms-player-sonos-parameters
  '("--use-local-speaker-list" "--no-env")
  "The arguments to `emms-player-sonos-command-name'."
  :type '(repeat string))

(defcustom emms-player-sonos-discover-command-name "sonos-discover"
  "The command name of sonos-discover."
  :type 'file)

(defcustom emms-player-sonos-discover-parameters '()
  "The arguments to `emms-player-sonos-discover-command-name'."
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
(emms-player-set emms-player-sonos 'seek #'emms-player-sonos-seek)
(emms-player-set emms-player-sonos 'seek-to #'emms-player-sonos-seek-to)

;; Global variables
(defvar emms-player-sonos-process-name "emms-player-sonos-process"
  "The name of the sonos player process.")

(defvar emms-player-sonos-current-speaker nil
  "Name or IP address of the currently playing Sonos speaker.")

(defun emms-player-sonos--run (name buffer &rest args)
  "Run sonos command with the given ARGS.
NAME is name for process.  It is modified if necessary to make it unique.
BUFFER is the buffer (or buffer name) to associate with the process.

The values of `emms-player-sonos-parameters' and `emms-player-sonos-speaker'
are prepended to the command automatically."
  (apply #'start-process
         name
         buffer
         emms-player-sonos-command-name
         (append emms-player-sonos-parameters
                 (cons emms-player-sonos-current-speaker
                       args))))

(defun emms-player-sonos-run (action &rest args)
  "Run sonos ACTION with the given ARGS.

The values of `emms-player-sonos-parameters' and `emms-player-sonos-speaker'
are prepended to the command automatically."
  (let ((name (concat emms-player-sonos-process-name "-" action)))
    (apply #'emms-player-sonos--run name nil action args)))

(defun emms-player-sonos-start (track)
  "Start the player process with the given TRACK."

  ;; Update the current speaker.
  (setq emms-player-sonos-current-speaker emms-player-sonos-speaker)

  (let* ((filename (emms-track-name track))
         (process (emms-player-sonos--run emms-player-sonos-process-name
                                          nil
                                          "play_file"
                                          filename)))
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

(defun emms-player-sonos-seek (sec)
  "Seek backward or forward by SEC seconds, depending on sign of SEC."
  (if (> sec 0)
      (emms-player-sonos-run "seek_forward"
                             (number-to-string sec))
    (emms-player-sonos-run "seek_back"
                           (number-to-string (- sec)))))

(defun emms-player-sonos-seek-to (sec)
  "Seek to SEC seconds from the start of the current track."
  (emms-player-sonos-run "seek"
                         (number-to-string sec)))

(defun emms-player-sonos-playable-p (track)
  "Return non-nil when we can play this TRACK."
  (and (executable-find emms-player-sonos-command-name)
       (memq (emms-track-type track)
             '(file))
       (string-match (emms-player-get emms-player-sonos 'regex)
                     (emms-track-name track))))

;;;###autoload
(defun emms-player-sonos-preference-f (track players)
  "Return `emms-player-sonos' if it's found in PLAYERS."
  (cond ((memq 'emms-player-sonos players)
         'emms-player-sonos)
        (emms-player-sonos--players-preference-f-backup
         (funcall emms-player-sonos--players-preference-f-backup
                  track players))
        (t (car players))))

;;; Volume

(defun emms-volume-sonos-change (amount)
  "Change volume up or down by AMOUNT, depending on sign of AMOUNT."
  (interactive "MVolume change amount (+ increase, - decrease): ")
  (emms-player-sonos-run "relative_volume" (number-to-string amount)))

;;; Convenience commands

(defvar emms-player-sonos-speakers nil
  "The list of available Sonos speakers.")

;;;###autoload
(defun emms-player-sonos-refresh-speaker-cache ()
  "Refresh the local speaker cache."
  (interactive)
  (let* ((command (string-join (cons emms-player-sonos-discover-command-name
                                     emms-player-sonos-discover-parameters)
                               " "))
         (output (shell-command-to-string command))
         (lines (split-string output "\n"))
         (narrowed-lines (seq-take-while (lambda (s)
                                           (not (string-empty-p s)))
                                         (seq-drop lines 5)))
         (rows (mapcar (lambda (line)
                         (split-string line "  +"))
                       narrowed-lines))
         (speakers (mapcar #'car rows)))
    (setq emms-player-sonos-speakers (cons "_all_" speakers))))

(defun emms-player-sonos--get-speakers ()
  "Return the list of available Sonos speakers."
  (if emms-player-sonos-speakers
      emms-player-sonos-speakers
    (emms-player-sonos-refresh-speaker-cache)))

;;;###autoload
(defun emms-player-sonos-set-speaker ()
  "Prompt and switch to new Sonos speaker name or IP address."
  (interactive)
  (let ((speaker (completing-read "Sonos speaker: "
                                  (emms-player-sonos--get-speakers)
                                  nil
                                  :require-match)))
    (setq emms-player-sonos-speaker speaker)))

;;; Minor mode

(defvar emms-player-sonos--player-list-backup)
(defvar emms-player-sonos--players-preference-f-backup)
(defvar emms-player-sonos--volume-change-function-backup)

(defun emms-player-sonos--mode-init ()
  "Initialization code for `emms-player-sonos-mode'."
  ;; Save old values
  (setq emms-player-sonos--player-list-backup emms-player-list
        emms-player-sonos--players-preference-f-backup emms-players-preference-f
        emms-player-sonos--volume-change-function-backup emms-volume-change-function)
  (setq emms-players-preference-f #'emms-player-sonos-preference-f
        emms-volume-change-function #'emms-volume-sonos-change)
  (add-to-list 'emms-player-list 'emms-player-sonos))

(defun emms-player-sonos--mode-clean-up ()
  "Cleanup code for `emms-player-sonos-mode'."
  ;; Restore old values
  (setq emms-player-list emms-player-sonos--player-list-backup
        emms-players-preference-f emms-player-sonos--players-preference-f-backup
        emms-volume-change-function emms-player-sonos--volume-change-function-backup))

;;;###autoload
(define-minor-mode emms-player-sonos-mode
  "Toggle EMMS Sonos player minor mode.
Sets `emms-player-list' and `emms-volume-change-function' for Sonos output."
  :global t
  (if emms-player-sonos-mode
      (emms-player-sonos--mode-init)
    (emms-player-sonos--mode-clean-up)))

(provide 'emms-player-sonos)
;;; emms-player-sonos.el ends here
