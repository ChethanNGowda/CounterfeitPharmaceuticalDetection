# OCR and medicine records

## Capture and extraction

The Flutter Medicine screen supports multiple named package views from the
camera or gallery. Original files are copied to private application storage,
with a bounded file size and image-derived extension. The stored profile keeps
the view label, capture time, raw OCR text, and extracted suggestions. The
legacy single `packagingImagePath` field remains readable for existing records.

The shared ML Kit OCR engine recognizes printed package text. The parser
suggests medicine name, manufacturer, strength, dosage form, batch number,
manufacturing date, expiry date, and MRP when patterns are sufficiently clear.
Every value remains editable. Missing/unclear values remain empty. OCR values
from different package views are compared; differing batch/date/MRP/manufacturer
values are reported with their source view and are not silently substituted.

OCR quality depends on readable focus, resolution, text size, lighting, and
orientation. Users should inspect raw OCR text and verify each field against
the package. OCR does not establish composition, identity, safety, or
authenticity.

## Expiry handling

Expiry values are saved as reviewed profile data. Full dates and supported
month/year formats are normalized by the existing parser; invalid or ambiguous
dates are not guessed. Unknown dates remain unknown. The status is computed
from the saved value and current date, so it should not be interpreted when
the source marking is unreadable or has not been reviewed.

## Barcode / QR values

The scanner decodes supported QR/barcode content and allows manual entry. The
decoded value is treated as an identifier string, not navigated as a URL and
not treated as proof. Official alert checking sends a reviewed identifier only
with the medicine fields and remains separate from image screening.

## Storage and retention

Medicine profile JSON is stored by the existing local persistence layer. New
photos are copied into app-private documents storage; removal only deletes
files owned by this app's medicine-image storage service. This is local device
storage, not a cloud backup. The current sync integration is record metadata
only and does not upload these photos. Deleting a profile removes its
app-managed photo files and local profile record. Device-level backup behavior
is controlled by Android backup exclusions; see [security and privacy](SECURITY_AND_PRIVACY.md).
