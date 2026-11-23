# -*- coding: utf-8 -*-
"""Генерация 5 HTML-шаблонов email для клиники 2432 (ELIXIR ESTATE).

Выход: docs/zabota/clients/2432/emails/*.html в кодировке CP1251
(требование PR2 / Teamly: meta charset=windows-1251).

Тексты писем: "РАССЫЛКА.docx" (правки от 23.11.2026).
Вёрстка: по эталонному шаблону Забота 2.0 (600px карточка, серая подложка,
синяя кнопка, обязательный блок отписки [%unsubscribe_link%]).

Структура письма:
    приветствие -> лид-абзац (жирный) -> абзацы текста -> закрывающий абзац
    (жирный) -> блок промокода -> кнопка {ref3} -> "Подробнее" -> подвал.
"""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "docs" / "zabota" / "clients" / "2432" / "emails"

BRAND = "ELIXIR ESTATE"
SITE = "https://elixe-samara.ru/"
LOGO_URL = "https://companies.zabota.space/storage/logos/logo_%20EX.png"
LOGO_WIDTH = 280
LOGO_HEIGHT = 111

PROMO_TERMS = (
    "Условия действия промокода: на все процедуры, кроме удаления новообразований, "
    "лечения рубца и удаления татуировок. Срок действия: месяц со дня получения рассылки."
)

TEMPLATE = """<!DOCTYPE html>
<html lang="ru">
<head>
<meta http-equiv="Content-Type" content="text/html; charset=windows-1251" />
<meta name="viewport" content="width=device-width, initial-scale=1" />
<title>{subject}</title>
</head>
<body style="margin:0; padding:0; background-color:#f3f4f6; font-family:Arial,Helvetica,sans-serif;">
<div style="display:none; max-height:0; overflow:hidden; mso-hide:all; font-size:1px; line-height:1px; color:#f3f4f6;">{preheader}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f3f4f6;">
<tr>
<td align="center" style="padding:24px 12px;">

<table role="presentation" width="600" cellpadding="0" cellspacing="0" border="0" style="width:100%; max-width:600px; background-color:#ffffff; border:1px solid #e5e7eb; border-radius:16px;">

<!-- шапка -->
<tr>
<td align="center" style="padding:28px 32px 0 32px;">
<a href="{site}" style="text-decoration:none;"><img src="{logo_url}" width="{logo_width}" height="{logo_height}" alt="{brand}" style="display:block; width:{logo_width}px; height:{logo_height}px; border:0; outline:none; text-decoration:none;" /></a>
</td>
</tr>

<!-- текст письма -->
<tr>
<td style="padding:22px 32px 0 32px; font-family:Arial,Helvetica,sans-serif;">
<p style="margin:0 0 16px 0; font-family:Arial,Helvetica,sans-serif; font-size:18px; line-height:1.4; font-weight:bold; color:#111827;">Здравствуйте!</p>
{lead}
{paragraphs}
{closing}
</td>
</tr>

<!-- промокод -->
<tr>
<td style="padding:10px 32px 0 32px; font-family:Arial,Helvetica,sans-serif;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:#f9fafb; border:1px solid #e5e7eb; border-radius:12px;">
<tr>
<td style="padding:20px 24px; font-family:Arial,Helvetica,sans-serif;">
<p style="margin:0 0 6px 0; font-size:11px; letter-spacing:1.5px; text-transform:uppercase; color:#6b7280;">Ваш персональный промокод на скидку 15%</p>
<p style="margin:0 0 10px 0; font-size:26px; line-height:1.2; font-weight:bold; letter-spacing:3px; color:#111827;">{promo}</p>
<p style="margin:0; font-size:13px; line-height:1.6; color:#4b5563;">Дарим только читателям писем от {brand}. Используйте его при записи на подходящие услуги.</p>
</td>
</tr>
</table>
<p style="margin:10px 0 0 0; font-size:11px; line-height:1.5; color:#9ca3af;">{promo_terms}</p>
</td>
</tr>

<!-- кнопка -->
<tr>
<td style="padding:24px 32px 0 32px; font-family:Arial,Helvetica,sans-serif;">
<table role="presentation" cellpadding="0" cellspacing="0" border="0">
<tr>
<td align="center" bgcolor="#2563eb" style="border-radius:8px;">
<a href="{{ref3}}" style="display:inline-block; padding:14px 30px; font-family:Arial,Helvetica,sans-serif; font-size:15px; font-weight:bold; color:#ffffff; text-decoration:none; border-radius:8px;">Запишитесь на консультацию</a>
</td>
</tr>
</table>
<p style="margin:16px 0 0 0; font-size:13px; line-height:1.6; color:#4b5563;">Подробнее об услуге: <a href="{more_url}" style="color:#2563eb; text-decoration:underline;">{more_text}</a></p>
</td>
</tr>

<!-- разделитель -->
<tr>
<td style="padding:28px 32px 0 32px;">
<div style="height:1px; background-color:#e5e7eb; line-height:1px; font-size:1px;">&nbsp;</div>
</td>
</tr>

<!-- подвал -->
<tr>
<td style="padding:20px 32px 0 32px; font-family:Arial,Helvetica,sans-serif;">
<p style="margin:0 0 8px 0; font-size:13px; font-weight:bold; color:#111827;">Контакты клиники</p>
<p style="margin:0 0 4px 0; font-size:12px; line-height:1.6; color:#6b7280;">Тел.: {phone}</p>
<p style="margin:0 0 4px 0; font-size:12px; line-height:1.6; color:#6b7280;">Адрес: {addr}</p>
<p style="margin:0 0 4px 0; font-size:12px; line-height:1.6; color:#6b7280;">Сайт: <a href="{site}" style="color:#2563eb; text-decoration:none;">{site_text}</a></p>
</td>
</tr>

<!-- юридический блок -->
<tr>
<td style="padding:16px 32px 28px 32px; font-family:Arial,Helvetica,sans-serif;">
<p style="margin:0; font-size:11px; line-height:1.5; color:#9ca3af;">Вы получили это письмо, потому что дали согласие на информирование при записи в клинику. Для изменения настроек рассылки обратитесь к администратору.<br />Если хотите отписаться от E-Mail рассылки, нажмите <a href="[%unsubscribe_link%]" style="color:#6b7280; text-decoration:underline;">отписаться от рассылки</a>.</p>
</td>
</tr>

</table>

</td>
</tr>
</table>
</body>
</html>
"""

LEAD_STY = ('<p style="margin:0 0 16px 0; font-family:Arial,Helvetica,sans-serif; '
            'font-size:16px; line-height:1.6; font-weight:bold; color:#111827;">{}</p>')
P_STY = ('<p style="margin:0 0 14px 0; font-family:Arial,Helvetica,sans-serif; '
         'font-size:15px; line-height:1.65; color:#374151;">{}</p>')
CLOSE_STY = ('<p style="margin:4px 0 0 0; font-family:Arial,Helvetica,sans-serif; '
             'font-size:15px; line-height:1.65; color:#374151;">{}</p>')

EMAILS = [
    {
        "file": "2432-email-01-uhodovye-procedury.html",
        "subject": "Кожа нуждается не только в коррекции, но и в уходе",
        "preheader": "Что делает защитный барьер и почему важна регулярность",
        "promo": "УХОД15",
        "lead": "А вы знали, что защитный барьер кожи помогает удерживать влагу и защищает её от внешних раздражителей?",
        "paragraphs": [
            "Он состоит из клеток и межклеточных липидов. Агрессивное очищение и чрезмерное отшелушивание могут нарушать его работу, провоцируя сухость, стянутость и повышенную чувствительность.",
            "Именно поэтому профессиональный уход - не просто приятный ритуал, а важная часть поддержания здоровья и качества кожи. Очищение, пилинги и уходовые процедуры помогают работать с текстурой, тоном и состоянием кожи, когда подобраны правильно.",
            "В Elixir Estate специалист оценит состояние вашей кожи и подберёт уход с учётом её потребностей.",
        ],
        "closing": "Не ждите, пока кожа начнёт сигнализировать о проблемах. Начните заботиться о ней уже сегодня. Запишитесь на профессиональный уход в Elixir Estate - пусть ваша кожа получает именно то, что ей необходимо.",
        "more_url": "https://elixe-samara.ru/services/kosmetologiya-licza/professionalnye-ukhody/",
        "more_text": "профессиональные уходы",
    },
    {
        "file": "2432-email-02-apparatnaya-kosmetologiya.html",
        "subject": "Свет и ультразвук: как работают разные технологии",
        "preheader": "Физические принципы процедур - простыми словами",
        "promo": "АППАРАТЫ15",
        "lead": "А вы знали, что фототерапия и SMAS-лифтинг воздействуют на ткани совершенно разными способами?",
        "paragraphs": [
            "Фототерапия использует свет определённых длин волн, воздействующий на мишени в коже - пигмент и гемоглобин. А SMAS-лифтинг работает за счёт сфокусированного ультразвука, воздействующего на заданную глубину тканей.",
            "В Elixir Estate для SMAS-лифтинга применяется аппарат UCOS-HIFU. Каждая технология решает свои задачи, поэтому важно правильно подобрать процедуру, а не ориентироваться только на популярность методики.",
            "Что подойдёт именно вашей коже? Это зависит от её состояния, анатомических особенностей, показаний и желаемого результата.",
        ],
        "closing": "Запишитесь на консультацию в Elixir Estate - врач поможет подобрать аппаратную методику, которая действительно соответствует вашим задачам.",
        "more_url": "https://elixe-samara.ru/services/smas-lifting/",
        "more_text": "SMAS-лифтинг UCOS-HIFU",
    },
    {
        "file": "2432-email-03-intimnoe-zdorovie.html",
        "subject": "Интимное здоровье: почему начинать стоит с консультации",
        "preheader": "Не все методы «интимного омоложения» одинаковы по показаниям и доказательности",
        "promo": "ГИНЕКОЛОГ15",
        "lead": "А вы знали, что процедуры интимного омоложения отличаются по механизму действия, показаниям и доказанной эффективности?",
        "paragraphs": [
            "Сухость, дискомфорт, изменения после родов — у каждого симптома могут быть разные причины, и важно не просто устранить проявления, а разобраться в их источнике.",
            "В Elixir Estate гинеколог поможет оценить состояние интимного здоровья, подобрать подходящий вариант коррекции и обсудить ожидаемый результат, возможные риски и противопоказания.",
        ],
        "closing": "Не выбирайте процедуру наугад — начните с консультации специалиста. Запишитесь на приём к гинекологу в Elixir Estate и найдите решение, подходящее именно вам.",
        "more_url": "https://elixe-samara.ru/services/ginekologiya/",
        "more_text": "гинекология в Elixir Estate",
    },
    {
        "file": "2432-email-04-uzi.html",
        "subject": "Как ультразвук помогает врачу увидеть больше",
        "preheader": "Коротко о принципе УЗИ и возможностях метода",
        "promo": "УЗИ15",
        "lead": "А вы знали, что УЗИ позволяет врачу наблюдать за органами и тканями в режиме реального времени - без рентгеновского излучения?",
        "paragraphs": [
            "Ультразвук помогает оценить структуру, размеры и расположение органов, а в некоторых режимах - движение и кровоток. Это важный инструмент диагностики, когда необходимо разобраться в причинах симптомов или проверить состояние здоровья.",
            "В Elixir Estate УЗИ проводится по медицинским показаниям, с учётом ваших жалоб и рекомендаций врача.",
        ],
        "closing": "Не откладывайте обследование, если организм подаёт сигналы. Своевременная диагностика помогает не оставлять вопросы о здоровье без ответа. Запишитесь на УЗИ в Elixir Estate - уделите внимание своему здоровью уже сегодня.",
        "more_url": "https://elixe-samara.ru/services/uzi/",
        "more_text": "ультразвуковая диагностика",
    },
    {
        "file": "2432-email-05-trihologiya.html",
        "subject": "Выпадение волос: почему важна диагностика кожи головы",
        "preheader": "Трихоскопия помогает врачу оценить волосы и кожу головы крупным планом",
        "promo": "ТРИХОЛОГ15",
        "lead": "А вы знали, что трихоскопия позволяет увидеть изменения кожи головы и волос, которые невозможно заметить невооружённым глазом?",
        "paragraphs": [
            "С помощью увеличения врач оценивает структуру волос, фолликулярные отверстия и состояние кожи, чтобы определить дальнейшую тактику диагностики.",
            "В Elixir Estate консультация трихолога проходит с использованием трихоскопа Aramo Smart Wizart.",
        ],
        "closing": "Не теряйте время на догадки и случайные средства. Узнайте, почему выпадают волосы, и начните действовать. Запишитесь на консультацию трихолога в Elixir Estate — начните с диагностики, а не с экспериментов.",
        "more_url": "https://elixe-samara.ru/services/trixologiya/",
        "more_text": "трихология",
    },
]


def build(email: dict) -> str:
    html = TEMPLATE.format(
        subject=email["subject"],
        preheader=email["preheader"],
        brand=BRAND,
        lead=LEAD_STY.format(email["lead"]),
        paragraphs="\n".join(P_STY.format(p) for p in email["paragraphs"]),
        closing=CLOSE_STY.format(email["closing"]),
        promo=email["promo"],
        promo_terms=PROMO_TERMS,
        more_url=email["more_url"],
        more_text=email["more_text"],
        site=SITE,
        site_text="elixe-samara.ru",
        phone="{cpn}",
        addr="{car}",
        logo_url=LOGO_URL,
        logo_width=LOGO_WIDTH,
        logo_height=LOGO_HEIGHT,
    )
    # {ref3} в шаблоне записан как {{ref3}} — вернуть одиночные скобки
    return html.replace("{{ref3}}", "{ref3}")


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for email in EMAILS:
        html = build(email)
        data = html.encode("cp1251", errors="strict")
        path = OUT / email["file"]
        path.write_bytes(data)
        print(f"{path.name}: {len(data)} байт")


if __name__ == "__main__":
    main()
