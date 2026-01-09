CREATE TABLE IF NOT EXISTS announcements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    content TEXT,
    image_url VARCHAR(500),
    type ENUM('announcement', 'campaign') DEFAULT 'announcement',
    target_app ENUM('driver', 'customer', 'both') DEFAULT 'both',
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP NULL
);

-- Example Data
INSERT INTO announcements (title, content, type, target_app, expires_at) VALUES 
('Hoş Geldiniz!', 'Taksibu ailesine hoş geldiniz. İlk yolculuğunuzda başarılar!', 'announcement', 'driver', DATE_ADD(NOW(), INTERVAL 30 DAY)),
('Yakıt Kampanyası', 'Anlaşmalı istasyonlarda %5 indirim!', 'campaign', 'driver', DATE_ADD(NOW(), INTERVAL 7 DAY));
