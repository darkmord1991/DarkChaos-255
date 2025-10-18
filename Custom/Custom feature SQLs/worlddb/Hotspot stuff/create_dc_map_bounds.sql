CREATE TABLE IF NOT EXISTS dc_map_bounds (
  mapid INT NOT NULL PRIMARY KEY,
  minX DOUBLE NOT NULL,
  maxX DOUBLE NOT NULL,
  minY DOUBLE NOT NULL,
  maxY DOUBLE NOT NULL,
  source VARCHAR(64) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

TRUNCATE TABLE dc_map_bounds;

INSERT INTO dc_map_bounds (mapid,minX,maxX,minY,maxY,source)
SELECT mapid,minX,maxX,minY,maxY,source FROM map_bounds;

SELECT COUNT(*) AS rows_in_dc_map_bounds FROM dc_map_bounds;
