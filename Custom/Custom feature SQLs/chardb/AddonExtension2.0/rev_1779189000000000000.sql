ALTER TABLE `dc_addon_protocol_errors`
    MODIFY COLUMN `request_type` enum('STANDARD','DC_JSON','DC_PLAIN','AIO','NATIVE')
    COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DC_PLAIN'
    COMMENT 'Protocol format: STANDARD=Blizz addon msg, DC_JSON=DC protocol+JSON, DC_PLAIN=DC protocol+plain, AIO=AIO framework, NATIVE=WotLK-Extensions custom opcode';

ALTER TABLE `dc_addon_protocol_log`
    MODIFY COLUMN `request_type` enum('STANDARD','DC_JSON','DC_PLAIN','AIO','NATIVE')
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci NOT NULL DEFAULT 'DC_PLAIN'
    COMMENT 'Protocol format: STANDARD=Blizz addon msg, DC_JSON=DC protocol+JSON, DC_PLAIN=DC protocol+plain, AIO=AIO framework, NATIVE=WotLK-Extensions custom opcode';