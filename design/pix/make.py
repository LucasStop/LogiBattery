"""Gera o QR Code do Pix (BR Code estático, sem valor) da chave aleatória de doação (#92).

Uso: PYTHONPATH=<dir com segno> python3 design/pix/make.py
Saída: design/pix/pix-qr.svg e o payload copia-e-cola em stdout.
"""
import segno

KEY = "dd226f83-02f0-4c80-bd23-322c9f5fa7ee"  # gitleaks:allow
NAME = "LUCAS STOPINSKI"  # até 25 caracteres
CITY = "BRASIL"  # até 15 caracteres


def tlv(tag: str, value: str) -> str:
    return f"{tag}{len(value):02d}{value}"


def crc16(data: str) -> str:
    crc = 0xFFFF
    for byte in data.encode():
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else crc << 1
            crc &= 0xFFFF
    return f"{crc:04X}"


body = (
    tlv("00", "01")
    + tlv("01", "11")
    + tlv("26", tlv("00", "br.gov.bcb.pix") + tlv("01", KEY))
    + tlv("52", "0000")
    + tlv("53", "986")
    + tlv("58", "BR")
    + tlv("59", NAME)
    + tlv("60", CITY)
    + tlv("62", tlv("05", "***"))
    + "6304"
)
payload = body + crc16(body)
segno.make(payload, error="m").save("design/pix/pix-qr.svg", scale=8, border=2, dark="#000", light="#fff")
print(payload)
