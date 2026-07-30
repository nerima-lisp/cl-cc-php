;;;; runtime-builtins-regex-date-test.lisp — src/runtime-builtins-regex-date.lisp — date/time and
;;;; the DateTime-compatible object builtins.
;;;;
;;;; date()/gmdate()/strtotime()/mktime() are already exercised extensively by PHP-source e2e
;;;; tests elsewhere; this file covers what those never reach: checkdate() and the object-style
;;;; date_create/date_format/date_modify/date_diff/DateTime::getTimestamp family, none of which
;;;; any existing test called by name.

(in-package :cl-cc-php/test)

(describe "PHP date/time: checkdate and the leap-year/days-in-month helpers"

(it-sequential "leap-year-p follows the Gregorian rule (div 4, not div 100 unless div 400)"
  (expect (cl-cc/php::%php-leap-year-p 2024) :to-be-truthy)
  (expect (cl-cc/php::%php-leap-year-p 2023) :to-be nil)
  (expect (cl-cc/php::%php-leap-year-p 1900) :to-be nil)
  (expect (cl-cc/php::%php-leap-year-p 2000) :to-be-truthy))

(it-sequential "days-in-month accounts for the leap-year February"
  (expect (cl-cc/php::%php-days-in-month 2 2024) :to-be 29)
  (expect (cl-cc/php::%php-days-in-month 2 2023) :to-be 28)
  (expect (cl-cc/php::%php-days-in-month 4 2023) :to-be 30)
  (expect (cl-cc/php::%php-days-in-month 1 2023) :to-be 31))

(it-sequential "checkdate accepts every real calendar date"
  (expect (cl-cc/php::%php-checkdate 2 29 2024) :to-be-truthy)
  (expect (cl-cc/php::%php-checkdate 1 31 2023) :to-be-truthy)
  (expect (cl-cc/php::%php-checkdate 4 30 2023) :to-be-truthy))

(it-sequential "checkdate rejects a day past the end of its month, even a leap February"
  ;; ENCODE-UNIVERSAL-TIME alone only range-checks day against 1-31, so it
  ;; accepted February 30th and April 31st as valid before %PHP-CHECKDATE
  ;; cross-checked against the month's real length.
  (expect (cl-cc/php::%php-checkdate 2 30 2023) :to-be nil)
  (expect (cl-cc/php::%php-checkdate 2 29 2023) :to-be nil)
  (expect (cl-cc/php::%php-checkdate 4 31 2023) :to-be nil))

(it-sequential "checkdate rejects an out-of-range month or a non-positive day"
  (expect (cl-cc/php::%php-checkdate 13 1 2023) :to-be nil)
  (expect (cl-cc/php::%php-checkdate 0 1 2023) :to-be nil)
  (expect (cl-cc/php::%php-checkdate 1 0 2023) :to-be nil))

  )

(describe "PHP date/time: the DateTime object-style builtins"

(it-sequential "date_create defaults to now and wraps a timestamp with __class__ DateTime"
  (let ((obj (cl-cc/php::%php-date-create)))
    (expect (cl-cc/php::%php-array-ref obj "__class__") :to-equal "DateTime")
    (expect (integerp (cl-cc/php::%php-array-ref obj "timestamp")) :to-be-truthy)))

(it-sequential "date_create parses an explicit datetime string via strtotime"
  (let ((obj (cl-cc/php::%php-date-create "1970-01-02 00:00:00")))
    (expect (cl-cc/php::%php-array-ref obj "timestamp") :to-be 86400)))

(it-sequential "date_create falls back to now for an unparseable string"
  (let ((obj (cl-cc/php::%php-date-create "not a date")))
    (expect (integerp (cl-cc/php::%php-array-ref obj "timestamp")) :to-be-truthy)))

(it-sequential "date_format formats the object's own timestamp"
  (let ((obj (cl-cc/php::%php-date-create "1970-01-02 00:00:00")))
    (expect (cl-cc/php::%php-date-format obj "Y-m-d") :to-equal "1970-01-02")))

(it-sequential "date_timestamp (DateTime::getTimestamp) returns the stored timestamp"
  (let ((obj (cl-cc/php::%php-date-create "1970-01-02 00:00:00")))
    (expect (cl-cc/php::%php-date-timestamp obj) :to-be 86400)))

(it-sequential "date_modify is currently a documented no-op: it returns OBJ unchanged"
  ;; PHP's date_modify() parses a relative-time string ("+1 day", "next
  ;; monday", ...) and applies it. This runtime does not implement that
  ;; parser yet, so %PHP-DATE-MODIFY ignores MODIFIER outright; this test
  ;; locks in that current, real behavior rather than leaving it unasserted.
  (let ((obj (cl-cc/php::%php-date-create "1970-01-02 00:00:00")))
    (expect (cl-cc/php::%php-date-modify obj "+1 day") :to-be obj)
    (expect (cl-cc/php::%php-date-timestamp obj) :to-be 86400)))

(it-sequential "date_diff breaks the gap between two DateTime objects into days/h/i/s"
  (let ((d1 (cl-cc/php::%php-date-create "1970-01-01 00:00:00"))
        (d2 (cl-cc/php::%php-date-create "1970-01-02 01:01:01")))
    (let ((interval (cl-cc/php::%php-date-diff d1 d2)))
      (expect (cl-cc/php::%php-array-ref interval "days") :to-be 1)
      (expect (cl-cc/php::%php-array-ref interval "h") :to-be 1)
      (expect (cl-cc/php::%php-array-ref interval "i") :to-be 1)
      (expect (cl-cc/php::%php-array-ref interval "s") :to-be 1)
      (expect (cl-cc/php::%php-array-ref interval "invert") :to-be 0))))

(it-sequential "date_diff sets invert when the first date is later than the second"
  (let ((d1 (cl-cc/php::%php-date-create "1970-01-02 00:00:00"))
        (d2 (cl-cc/php::%php-date-create "1970-01-01 00:00:00")))
    (expect (cl-cc/php::%php-array-ref (cl-cc/php::%php-date-diff d1 d2) "invert") :to-be 1)))

  )

(describe "PHP date/time: timezone name/offset helpers"

(it-sequential "timezone-name trims surrounding whitespace"
  (expect (cl-cc/php::%php-timezone-name "  UTC  ") :to-equal "UTC"))

(it-sequential "timezone-offset-seconds looks up a known identifier, NIL for an unknown one"
  (expect (cl-cc/php::%php-timezone-offset-seconds "Asia/Tokyo") :to-be 32400)
  (expect (cl-cc/php::%php-timezone-offset-seconds "Not/AZone") :to-be nil))

(it-sequential "date_default_timezone_set/get round-trip a known timezone and reject an unknown one"
  (let ((saved (cl-cc/php::%php-date-default-timezone-get)))
    (unwind-protect
        (progn
          (expect (cl-cc/php::%php-date-default-timezone-set "Asia/Tokyo") :to-be-truthy)
          (expect (cl-cc/php::%php-date-default-timezone-get) :to-equal "Asia/Tokyo")
          (expect (cl-cc/php::%php-date-default-timezone-set "Not/AZone") :to-be nil)
          (expect (cl-cc/php::%php-date-default-timezone-get) :to-equal "Asia/Tokyo"))
      (cl-cc/php::%php-date-default-timezone-set saved))))

  )
