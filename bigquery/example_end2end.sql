/**
    Copyright 2025 Google LLC
    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at
        https://www.apache.org/licenses/LICENSE-2.0
    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
 */

-- This shows an example of FeedGen running end-to-end with sample data.

CREATE OR REPLACE TABLE `[DATASET]`.InputProcessing (
  id STRING,
  title STRING,
  description STRING,
  brand STRING,
  gender STRING,
  category STRING,
  size STRING,
  color STRING,
  material STRING
);

INSERT INTO `[DATASET]`.InputProcessing (id, title, description, brand, gender, category, size, color, material)
VALUES
  ('2480', 'ASICS Women\'s Performance Running Capri Tight', 'ASICS Women\'s Performance R', 'ASICS', 'Women\'s', 'Active', 'S', 'Black', 'Cotton, Polyester'),
  ('21084', 'Agave Men\'s Waterman Relaxed Grey Jean', 'Agave Men\'s Waterman Relaxed', 'Agave', 'Men\'s', 'Jeans', '33x30', 'Denim', 'Denim'),
  ('27569', '2XU Men\'s Swim Compression Long Sleeve Top', '2XU Men\'s Swim Compression L', '2XU', 'Men\'s', 'Swim', 'M', 'PWX Fabric', 'PWX Fabric'),
  ('8089', 'Seven7(r) Smart Satin Evening Suit with Flute Skirt', 'Seven7 Smart Satin Evening Suit with Flu', 'Seven7(r)', 'Women\'s', 'Suits', 'L', 'Beige', 'Satin');

CREATE OR REPLACE TABLE `[DATASET]`.InputFiltered (
  id STRING,
  title STRING,
  description STRING,
  brand STRING,
  gender STRING,
  category STRING,
  size STRING,
  color STRING,
  material STRING
);

INSERT INTO `[DATASET]`.InputFiltered (id, title, description, brand, gender, category, size, color, material)
SELECT id, title, description, brand, gender, category, size, color, material FROM `[DATASET]`.InputProcessing;


CREATE OR REPLACE TABLE `[DATASET]`.Examples AS
WITH Examples AS (
  SELECT * FROM UNNEST(ARRAY<STRUCT<id STRING, title STRING, description STRING>>[
    STRUCT(
      '2480',
      """ASICS Women's Performance Running Capri Tight, Black, Size S, Cotton, Polyester, Capri Length, Reflective Details, Secure Pocket""",
      """The ASICS Women's Performance Running Capri Tight is a high-quality, versatile tight perfect for running, yoga, and other athletic activities. The tight is made with soft, stretchy fabric that wicks away sweat to keep you cool and dry. It also features reflective details for added visibility at night. The tight has a secure pocket for storing small items such as keys or a credit card. The ASICS Women's Performance Running Capri Tight is available in black and white and comes in sizes small to large.""")
  ])
)
SELECT
  id,
  TO_JSON_STRING((SELECT AS STRUCT * EXCEPT(id) FROM UNNEST([I]))) AS properties,
  E.title,
  E.description
FROM Examples AS E
INNER JOIN `[DATASET]`.InputProcessing AS I USING (id);


CREATE OR REPLACE TABLE `[DATASET]`.Output AS
SELECT
  id,
  CAST(NULL AS STRING) AS title,
  CAST(NULL AS STRING) AS description,
  0 AS tries
FROM `[DATASET]`.InputFiltered;

CALL `[DATASET]`.BatchedUpdateTitles(2, 'German', NULL, NULL, NULL);
CALL `[DATASET]`.BatchedUpdateDescriptions(2, 'German', NULL, NULL, NULL);
