(in-package :cl-cc-php/test)

(describe
  "PHP image metadata builtins"
  (it-sequential
    "image_type_info maps IMAGETYPE_* integers to extension and mime, nil for unknown"
    (expect (cl-cc/php::%php-image-type-info 1) :to-equal "gif")
    (expect (cl-cc/php::%php-image-type-info 2) :to-equal "jpeg")
    (expect (cl-cc/php::%php-image-type-info 3) :to-equal "png")
    (expect (cl-cc/php::%php-image-type-info 18) :to-equal "webp")
    (expect (cl-cc/php::%php-image-type-info 21) :to-equal "svg")
    (expect (cl-cc/php::%php-image-type-info 999) :to-be nil))
  (it-sequential
    "image_type_to_extension honors the leading-dot flag and unknown types"
    (expect (cl-cc/php::%php-image-type-to-extension 2) :to-equal ".jpeg")
    (expect (cl-cc/php::%php-image-type-to-extension 2 nil) :to-equal "jpeg")
    (expect (cl-cc/php::%php-image-type-to-extension 999) :to-be nil))
  (it-sequential
    "image_type_to_mime_type maps known types and returns nil otherwise"
    (expect (cl-cc/php::%php-image-type-to-mime-type 3) :to-equal "image/png")
    (expect (cl-cc/php::%php-image-type-to-mime-type 2) :to-equal "image/jpeg")
    (expect (cl-cc/php::%php-image-type-to-mime-type 999) :to-be nil))
  (it-sequential
    "bytes-prefix-p matches a byte prefix, respects start offset, and bounds"
    (expect
      (cl-cc/php::%php-bytes-prefix-p #(255 216 255) '(255 216))
      :to-be-truthy)
    (expect (cl-cc/php::%php-bytes-prefix-p #(255 216 255) '(137 80)) :to-be nil)
    (expect (cl-cc/php::%php-bytes-prefix-p #(255) '(255 216)) :to-be nil)
    (expect
      (cl-cc/php::%php-bytes-prefix-p #(0 255 216) '(255 216) 1)
      :to-be-truthy))
  (it-sequential
    "bytes-match-string-p compares bytes to an ASCII string"
    (expect
      (cl-cc/php::%php-bytes-match-string-p #(82 73 70 70) 0 "RIFF")
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-bytes-match-string-p #(82 73 70 70) 0 "WEBP")
      :to-be
      nil))
  (it-sequential
    "ascii-string and the big-/little-endian integer readers"
    (expect (cl-cc/php::%php-bytes-ascii-string #(72 73) 0 2) :to-equal "HI")
    (expect (cl-cc/php::%php-u16-be #(1 2) 0) :to-be 258)
    (expect (cl-cc/php::%php-u16-le #(1 2) 0) :to-be 513)
    (expect (cl-cc/php::%php-u32-be #(0 0 1 0) 0) :to-be 256))
  (it-sequential
    "webp-bytes-p requires the RIFF....WEBP container"
    (expect
      (cl-cc/php::%php-webp-bytes-p #(82 73 70 70 0 0 0 0 87 69 66 80))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-webp-bytes-p #(82 73 70 70 0 0 0 0 0 0 0 0))
      :to-be
      nil))
  (it-sequential
    "avif and heif detection read ISO-BMFF ftyp brands"
    (expect
      (cl-cc/php::%php-avif-bytes-p #(0 0 0 0 102 116 121 112 97 118 105 102))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-heif-bytes-p #(0 0 0 0 102 116 121 112 104 101 105 99))
      :to-be-truthy)
    (expect
      (cl-cc/php::%php-avif-bytes-p #(0 0 0 0 102 116 121 112 104 101 105 99))
      :to-be
      nil)
    (expect (cl-cc/php::%php-avif-bytes-p #(0 0 0 0 0 0 0 0 0 0 0 0)) :to-be nil))
  (it-sequential
    "image_type_from_bytes recognizes gif/jpeg/png/webp/avif/heif and unknown"
    (expect
      (cl-cc/php::%php-image-type-from-bytes #(71 73 70 56 55 97 0 0))
      :to-be
      1)
    (expect (cl-cc/php::%php-image-type-from-bytes #(255 216 255 0)) :to-be 2)
    (expect
      (cl-cc/php::%php-image-type-from-bytes #(137 80 78 71 13 10 26 10))
      :to-be
      3)
    (expect
      (cl-cc/php::%php-image-type-from-bytes #(82 73 70 70 0 0 0 0 87 69 66 80))
      :to-be
      18)
    (expect
      (cl-cc/php::%php-image-type-from-bytes
        #(0 0 0 0 102 116 121 112 97 118 105 102))
      :to-be
      19)
    (expect
      (cl-cc/php::%php-image-type-from-bytes
        #(0 0 0 0 102 116 121 112 104 101 105 99))
      :to-be
      20)
    (expect (cl-cc/php::%php-image-type-from-bytes #(0 1 2 3)) :to-be nil))
  (it-sequential
    "svg-text-p finds a <svg tag anywhere in the text"
    (expect (cl-cc/php::%php-svg-text-p "<svg xmlns='x'>") :to-be-truthy)
    (expect (cl-cc/php::%php-svg-text-p "hello") :to-be nil))
  (it-sequential
    "png-dimensions and gif-dimensions read width/height from headers"
    (expect
      (cl-cc/php::%php-png-dimensions
        #(137 80 78 71 13 10 26 10 0 0 0 13 73 72 68 82 0 0 0 16 0 0 0 8))
      :to-be
      16)
    (expect
      (cl-cc/php::%php-gif-dimensions #(71 73 70 56 57 97 16 0 8 0))
      :to-be
      16))
  (it-sequential
    "jpeg-sof-marker-p classifies frame markers, jpeg-dimensions reads SOF size"
    (expect (cl-cc/php::%php-jpeg-sof-marker-p 192) :to-be-truthy)
    (expect (cl-cc/php::%php-jpeg-sof-marker-p 216) :to-be nil)
    (expect
      (cl-cc/php::%php-jpeg-dimensions #(255 216 255 192 0 17 8 0 16 0 32))
      :to-be
      32)
    (expect (cl-cc/php::%php-jpeg-dimensions #(1 2 3)) :to-be nil))
  (it-sequential
    "svg-start-tag extracts the opening tag, nil when absent"
    (expect
      (cl-cc/php::%php-svg-start-tag "<svg width=\"100\">rest")
      :to-equal
      "<svg width=\"100\"")
    (expect (cl-cc/php::%php-svg-start-tag "no svg here") :to-be nil))
  (it-sequential
    "the small XML character and whitespace-skipping helpers"
    (expect (cl-cc/php::%php-svg-name-char-p #\a) :to-be-truthy)
    (expect (cl-cc/php::%php-svg-name-char-p #\Space) :to-be nil)
    (expect (cl-cc/php::%php-xml-space-p #\Space) :to-be-truthy)
    (expect (cl-cc/php::%php-xml-space-p #\a) :to-be nil)
    (expect (cl-cc/php::%php-skip-xml-space "  ab" 0) :to-be 2))
  (it-sequential
    "svg-attribute-value reads double-quoted, single-quoted, and missing attrs"
    (expect
      (cl-cc/php::%php-svg-attribute-value
        "<svg width=\"100\" height=\"50\">"
        "width")
      :to-equal
      "100")
    (expect
      (cl-cc/php::%php-svg-attribute-value "<svg width='42'>" "width")
      :to-equal
      "42")
    (expect
      (cl-cc/php::%php-svg-attribute-value "<svg height=\"50\">" "width")
      :to-be
      nil))
  (it-sequential
    "svg-number-value parses integers, collapses whole floats, and defaults to 0"
    (expect (cl-cc/php::%php-svg-number-value "100") :to-be 100)
    (expect (cl-cc/php::%php-svg-number-value "10.0") :to-be 10)
    (expect (cl-cc/php::%php-svg-number-value "abc") :to-be 0))
  (it-sequential
    "svg-dimension splits number and unit, defaulting empty to 0 px"
    (expect (cl-cc/php::%php-svg-dimension "100px") :to-be 100)
    (expect (cl-cc/php::%php-svg-dimension "50") :to-be 50)
    (expect (cl-cc/php::%php-svg-dimension nil) :to-be 0))
  (it-sequential
    "svg-dimensions reads width from the svg tag"
    (expect
      (cl-cc/php::%php-svg-dimensions "<svg width=\"100\" height=\"50\">")
      :to-be
      100))
  (it-sequential
    "image-dimensions-and-units dispatches on image type"
    (expect
      (cl-cc/php::%php-image-dimensions-and-units
        3
        #(137 80 78 71 13 10 26 10 0 0 0 13 73 72 68 82 0 0 0 16 0 0 0 8)
        nil)
      :to-be
      16)
    (expect
      (cl-cc/php::%php-image-dimensions-and-units
        21
        nil
        "<svg width=\"100\" height=\"50\">")
      :to-be
      100)
    (expect (cl-cc/php::%php-image-dimensions-and-units 99 nil nil) :to-be 0))
  (it-sequential
    "getimagesize / exif_imagetype / detect-image-type read a real PNG file"
    (let ((png
          (coerce
            #(137 80 78 71 13 10 26 10 0 0 0 13 73 72 68 82 0 0 0 16 0 0 0 8 8 2 0 0 0)
            '(vector (unsigned-byte 8))))
          (path
          (merge-pathnames
            (format nil "cc-php-io-image-~A.png" (random 100000000))
            (uiop:temporary-directory))))
      (unwind-protect (progn
          (with-open-file (out
              path
              :direction
              :output
              :element-type
              '(unsigned-byte 8)
              :if-exists
              :supersede
              :if-does-not-exist
              :create)
            (write-sequence png out))
          (let ((file (namestring path)))
            (expect (cl-cc/php::%php-exif-imagetype file) :to-be 3)
            (expect (cl-cc/php::%php-detect-image-type file) :to-be 3)
            (let ((info (cl-cc/php::%php-getimagesize file)))
              (expect (cl-cc/php::%php-array-ref info 0) :to-be 16)
              (expect (cl-cc/php::%php-array-ref info 1) :to-be 8)
              (expect (cl-cc/php::%php-array-ref info 2) :to-be 3)
              (expect (cl-cc/php::%php-array-ref info "mime") :to-equal "image/png"))))
        (ignore-errors (delete-file path))))))
