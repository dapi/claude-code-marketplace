# Media Upload Trigger Examples

## ✅ Should Activate

### 📸 Screenshots (EN)

- "upload screenshot"
- "save screenshot to s3"
- "attach screenshot"
- "upload the last screenshot"
- "upload playwright screenshot"
- "upload the screenshot I just took"
- "save this screenshot"
- "share the screenshot"
- "get public link for screenshot"

### 📸 Screenshots (RU)

- "загрузи скриншот"
- "сохрани скриншот"
- "приложи скриншот"
- "загрузи последний скриншот"
- "залей скриншот в s3"
- "получи ссылку на скриншот"

### 🖼️ Images (EN)

- "upload image"
- "save image to s3"
- "upload picture"
- "upload photo"
- "upload this png"
- "upload the jpg file"
- "share image"
- "upload gif"
- "save webp to bucket"
- "upload svg file"
- "attach image to issue"
- "get public link for image"

### 🖼️ Images (RU)

- "загрузи картинку"
- "сохрани изображение"
- "залей фото"
- "загрузи эту png"
- "загрузи jpg файл"
- "приложи картинку"
- "получи публичную ссылку на изображение"

### 📁 Explicit Paths (EN)

- "upload /tmp/screenshot.png"
- "upload ./images/logo.png to s3"
- "save ~/Downloads/photo.jpg"
- "upload /home/user/image.gif"
- "upload the file at /tmp/page-2024-01-31.png"

### 📁 Explicit Paths (RU)

- "загрузи /tmp/screenshot.png"
- "залей файл ./images/logo.png"
- "сохрани ~/Downloads/photo.jpg"

### 📦 Batch Upload (EN)

- "upload all screenshots from ./folder/"
- "upload all png from ./screenshots/"
- "upload all images in ./images/"
- "upload *.jpg from current directory"
- "upload all files from ./media/"

### 📦 Batch Upload (RU)

- "загрузи все скриншоты из ./folder/"
- "загрузи все png из ./screenshots/"
- "залей все картинки из ./images/"
- "загрузи все jpg файлы"

### 📎 General Upload Commands (EN)

- "upload to bucket"
- "save to s3"
- "get public link"
- "upload file to cdn"
- "save to minio"
- "upload media file"
- "share file via s3"

### 📎 General Upload Commands (RU)

- "загрузи в s3"
- "сохрани в bucket"
- "получи публичную ссылку"
- "залей в cdn"
- "загрузи медиафайл"

### 📜 History Commands (EN)

- "show recent uploads"
- "last uploads"
- "show upload history"
- "what did I upload recently"
- "find yesterday's uploads"

### 📜 History Commands (RU)

- "покажи последние загрузки"
- "история загрузок"
- "что я загружал"
- "найди вчерашние загрузки"

### 📄 Documents (EN)

- "upload pdf to s3"
- "save document to bucket"
- "upload this pdf file"

### 📄 Documents (RU)

- "загрузи pdf в s3"
- "сохрани документ"
- "залей этот pdf"

## ❌ Should NOT Activate

### General Questions
- "what is S3?"
- "how does MinIO work?"
- "explain mc cli"
- "what are image formats?"
- "что такое S3?"

### Installation/Setup (without upload intent)
- "install minio-mc"
- "how to configure mc alias"
- "set up s3 bucket"
- "create bucket in minio"
- "установи minio-mc"

### Downloading (opposite direction)
- "download image from s3"
- "get file from bucket"
- "fetch image from cdn"
- "скачай картинку из s3"
- "получи файл из bucket"

### File Operations (not upload)
- "delete image from s3"
- "list files in bucket"
- "move file in s3"
- "rename file in bucket"
- "удали файл из s3"

### Image Editing
- "resize image"
- "convert png to jpg"
- "compress image"
- "edit screenshot"
- "изменить размер картинки"

### Taking Screenshots (without upload)
- "take a screenshot"
- "capture the screen"
- "screenshot this page"
- "сделай скриншот"

### Comparison/Analysis
- "compare s3 vs azure blob"
- "which is better minio or aws s3"

## 🎯 Key Trigger Words

### Verbs (EN)
- upload, save, attach, share, get (link), put

### Verbs (RU)
- загрузи, сохрани, приложи, залей, получи (ссылку)

### Nouns (EN)
- screenshot, image, picture, photo, file, media, png, jpg, gif, webp, svg, pdf

### Nouns (RU)
- скриншот, картинка, изображение, фото, файл, медиа

### Destinations (EN)
- s3, bucket, cdn, minio, storage

### Destinations (RU)
- s3, bucket, cdn, хранилище

### Context Patterns
- "to s3", "to bucket", "to cdn"
- "в s3", "в bucket"
- "public link", "публичная ссылка"
- "last/recent uploads", "последние загрузки"
