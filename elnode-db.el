;;; elnode-db.el --- a database interface  -*- lexical-binding: t -*-

;; Copyright (C) 2012  Nic Ferrier

;; Author: Nic Ferrier <nferrier@ferrier.me.uk>
;; Maintainer: Nic Ferrier <nferrier@ferrier.me.uk>
;; Created: 30 June 2012
;; Keywords: lisp, http, hypermedia

;; This file is NOT part of GNU Emacs.

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; This is a simple database interface and implementation.
;;
;; It should be possible to specify any kind of key/value database
;; with this interface.
;;
;; The supplied implementation is an Emacs hash-table implementation
;; backed with serializing objects.  It is NOT intended for anything
;; other than very simple use cases and will not scale very well at
;; all.

;; However, other implementations (mongodb, redis or PostgreSQL
;; hstore) would be easy to implement and fit in here.

;;; Source code
;;
;; elnode's code can be found here:
;;   http://github.com/nicferrier/elnode

;;; Style note
;;
;; This codes uses the Emacs style of:
;;
;;    elnode--private-function
;;
;; for private functions.


;;; Code:

(eval-when-compile
  (require 'cl))

(defvar elnode-db--types (make-hash-table :test 'eq)
  "Hash of database type ids against funcs?")

(defun* elnode-db-make (reference)
  ;; we should look it up in the types somehow
  (if (and (listp reference)
           (eq
            'elnode-db-hash
            (car reference)))
      ;; this should be part of what we find when we look it up?
      (elnode-db-hash reference)
      ;; there should be a specific db error
      (error "no such database implementation")))

(defun elnode-db-get (key db)
  (funcall (plist-get db :get) key db))

(defun elnode-db-put (key value db)
  (funcall (plist-get db :put) key value db))

(defun elnode-db-map (func db &optional query)
  ;; The query should be implemented here, around the func
  (funcall (plist-get db :map) func db))


(defun elnode-db-hash (reference)
  "Make a db-hash database.

REFERENCE comes from the call to `elnode-db-make' and should
include a `:filename' key arg to point to a file.

If the filename exists then it is loaded into the database."
  (let* ((filename (plist-get reference :filename))
         (db (list
              :db (make-hash-table :test 'equal)
              :get 'elnode-db-hash-get
              :put 'elnode-db-hash-put
              :map 'elnode-db-hash-map
              :filename filename)))
    (when (and filename
               (file-exists-p filename))
      (elnode-db-hash--read db))
    ;; Return the database
    db))

(defun elnode-db-hash--read (db)
  "Loads the DB."
  (let ((filename (plist-get db :filename)))
    (when filename
      (load-file filename)
      (plist-put db :db (symbol-value (intern filename))))))

(defun elnode-db-hash--save (db)
  "Saves the DB."
  (let ((filename (plist-get db :filename)))
    (when filename
      (with-temp-file filename
        (erase-buffer)
        (let ((fmt-obj (format
                        "(setq %s (eval-when-compile %s))"
                        (intern filename)
                        (plist-get db :db))))
          (insert fmt-obj)))
      (byte-compile-file filename)
      (delete-file filename))))

(defun elnode-db-hash-get (key db)
  (let ((v (gethash key (plist-get db :db))))
    v))

(defun elnode-db-hash-map (func db)
  (maphash func (plist-get db :db)))

(defun elnode-db-hash-put (key value db)
  (let ((v (puthash key value (plist-get db :db))))
    ;; Instead of saving every time we could simply signal an update
    ;; and have a timer do the actual save.
    (elnode-db-hash--save db)
    v))

(ert-deftest elnode-db-get ()
  ;; Make a hash-db with no filename
  (let ((db (elnode-db-make '(elnode-db-hash))))
    (should-not (elnode-db-get "test-key" db))
    (elnode-db-put "test-key" 321 db)
    (should
     (equal
      321
      (elnode-db-get "test-key" db)))))

(provide 'elnode-db)

;;; elnode-db.el ends here
