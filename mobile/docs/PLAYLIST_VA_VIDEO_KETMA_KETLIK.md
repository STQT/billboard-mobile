# Videolar ketma-ketligi — to‘liq ma’lumot

## 1. API dan nima keladi?

Playlist **`/playlists/current`** endpoint orqali olinadi. Javobda quyidagi struktura bor:

### 1.1. `contract_videos` (shartnoma videolari)

Har bir elementda:
- **`video_id`** — video ID
- **`start_time`** — boshlanish vaqti (soat boshidan sekundlarda, 0–3600)
- **`end_time`** — tugash vaqti (soat boshidan sekundlarda, 0–3600)
- **`duration`** — videoning davomiyligi (sekund)
- **`frequency`** — bu video soat davomida necha marta o‘ynatilishi kerak
- **`file_path`** — fayl yo‘li (masalan `/videos/filename.mp4`)
- **`media_url`** — to‘liq media URL

**Ma’nosi:** Contract videolar ma’lum **vaqt oralig‘ida** (start_time … end_time) o‘ynatilishi kerak bo‘lgan reklamalar.

### 1.2. `filler_videos` (to‘ldiruvchi videolar)

Har bir elementda:
- **`video_id`**
- **`duration`**
- **`file_path`**
- **`media_url`**

**Ma’nosi:** Shartnoma reklamalari bo‘lmagan vaqtlarda (yoki oraliqlarda) o‘ynatiladigan videolar. Ularda vaqt oralig‘i (start/end) yo‘q — ular bo‘sh vaqtlarni to‘ldiradi.

### 1.3. `video_sequence`

- **Turi:** `List<int>` — **video_id** larning tartiblangan ro‘yxati.
- **Ma’nosi:** Backend ushbu ro‘yxatda **soat davomida videolar o‘ynatiladigan aniq ketma-ketlikni** beradi.  
  Ya’ni: birinchi element birinchi o‘ynatiladigan video ID, ikkinchi — ikkinchi, va hokazo.

---

## 2. Ilovada ketma-ketlik qanday ishlatiladi?

### 2.1. Playlist yuklanishi

1. **ApiService** → `getCurrentPlaylist()` → JSON javob.
2. **Playlist.fromJson()** → `contract_videos`, `filler_videos`, `video_sequence` parse qilinadi.
3. **VideoService.loadPlaylist()** → `_currentPlaylist` saqlanadi, keyin `_loadVideos()` chaqiriladi.

### 2.2. Video ro‘yxatining yig‘ilishi (`_loadVideos`)

- **Qaysi ID lar ishlatiladi:**  
  `uniqueVideoIds = _currentPlaylist!.allVideoIds`  
  Bu xossada **faqat `video_sequence`** dan olingan ID lar ishlatiladi (takrorlarsiz).

- **Qanday tartib:**  
  Ro‘yxat **strict** tarzda **`video_sequence`** tartibida quriladi:

```dart
_videos = _currentPlaylist!.videoSequence
    .where((id) => videoMap.containsKey(id))
    .map((id) => videoMap[id]!)
    .toList();
```

Demak:
- **O‘ynatish tartibi** = **`video_sequence`** dagi tartib.
- Bir xil video_id `video_sequence` da bir necha marta kelsa, u necha marta ro‘yxatda bo‘lsa, shuncha marta o‘ynatiladi (chunki har bir ID uchun bitta `Video` ob’ekt bor, lekin ro‘yxatda takrorlanadi).

### 2.3. Qaysi vaqtda qaysi video o‘ynatiladi?

- **Vaqt (soat ichidagi daqiqa/sekund)** ilovada **hisobga olinmaydi**.  
  Ilova faqat **ro‘yxat tartibini** biladi: 1‑video tugadi → 2‑video, 2‑video tugadi → 3‑video, … oxirigacha, keyin yana boshiga (cycle).
- **Qaysi birinchi** o‘ynatiladi: **`_videos[0]`** — ya’ni `video_sequence` ning birinchi elementi.
- Keyingi har bir video: **`video_sequence`** dagi keyingi pozitsiyadagi video.

**Qisqacha:**  
“Qaysi vaqtda qaysi biri qo‘yiladi” **backend** tomonida **`video_sequence`** generatsiya qilishda hal qilinadi. Ilova shu ketma-ketlikni **o‘zgartirmaydi**, xuddi shu tartibda chcyclically o‘ynatadi.

---

## 3. Contract va Filler — hozirgi kodda

| Ma’lumot                    | API da bor      | Ilovada ishlatilishi        |
|----------------------------|-----------------|-----------------------------|
| **Contract:** start_time, end_time, frequency | Ha             | **Yo‘q** — faqat modelda saqlanadi |
| **Filler:** duration, file_path, media_url    | Ha             | **Yo‘q** — faqat modelda    |
| **video_sequence**         | Ha              | **Ha** — faqat shu tartib ishlatiladi |

Ya’ni:  
- **Contract** va **filler** ning “qaysi vaqtda” va “necha marta” ma’lumoti **backend** da **`video_sequence`** ni yaratishda ishlatilishi kerak.  
- Mobil ilova **`video_sequence`** ni “soatlik jadval” deb qabul qiladi va shu tartibda abadiy cycle da o‘ynatadi.

---

## 4. Xulosa

- **Ketma-ketlik:** API dan kelgan **`video_sequence`** — aynan shu tartibda videolar o‘ynatiladi.
- **“Qaysi vaqtda qaysi biri”:** Backend **contract_videos** (vaqt slotlari) va **filler_videos** (to‘ldiruvchi) bo‘yicha **video_sequence** ni generatsiya qiladi; ilova faqat shu ro‘yxatni ketma-ket o‘ynatadi, vaqt hisobi ilovada yo‘q.
- **Contract videolar** — vaqt oralig‘i (start_time/end_time) va frequency backend da ishlatiladi.
- **Filler videolar** — bo‘sh vaqtlarni to‘ldirish uchun; ular ham **video_sequence** orqali o‘ynatiladi.

Agar backend **video_sequence** ni to‘g‘ri (vaqt va contract/filler qoidalariga mos) generatsiya qilsa, ilovada ham tartib to‘g‘ri bo‘ladi.
