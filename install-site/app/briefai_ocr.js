(function () {
  const MAX_PDF_PAGES = 20;

  async function recognizeWithWorker(worker, source) {
    const result = await worker.recognize(source);
    return (result?.data?.text || '').trim();
  }

  async function prepareImage(bytes, mimeType) {
    const blob = new Blob([bytes], {type: mimeType});
    if (!window.createImageBitmap) return blob;
    const bitmap = await createImageBitmap(blob, {
      imageOrientation: 'from-image',
    });
    try {
      const maxSide = Math.max(bitmap.width, bitmap.height);
      const scale = Math.min(1, 2400 / maxSide);
      const canvas = document.createElement('canvas');
      canvas.width = Math.max(1, Math.round(bitmap.width * scale));
      canvas.height = Math.max(1, Math.round(bitmap.height * scale));
      const context = canvas.getContext('2d', {alpha: false});
      context.fillStyle = '#ffffff';
      context.fillRect(0, 0, canvas.width, canvas.height);
      context.filter = 'contrast(1.15) brightness(1.03)';
      context.drawImage(bitmap, 0, 0, canvas.width, canvas.height);
      context.filter = 'none';
      return canvas;
    } finally {
      bitmap.close();
    }
  }

  window.briefAiRecognizeDocument = async function (rawBytes, mimeType) {
    if (!window.Tesseract) {
      throw new Error('Lokalni OCR još nije učitan. Pokušajte ponovo.');
    }
    const bytes = rawBytes instanceof Uint8Array
      ? rawBytes
      : new Uint8Array(rawBytes);
    const worker = await window.Tesseract.createWorker('deu+eng');
    try {
      if (mimeType !== 'application/pdf') {
        const source = await prepareImage(bytes, mimeType);
        return await recognizeWithWorker(worker, source);
      }

      const pdfjs = await import(
        'https://cdn.jsdelivr.net/npm/pdfjs-dist@6.1.200/build/pdf.min.mjs'
      );
      pdfjs.GlobalWorkerOptions.workerSrc =
        'https://cdn.jsdelivr.net/npm/pdfjs-dist@6.1.200/build/pdf.worker.min.mjs';
      const pdf = await pdfjs.getDocument({data: bytes}).promise;
      if (pdf.numPages > MAX_PDF_PAGES) {
        throw new Error(`PDF može imati najviše ${MAX_PDF_PAGES} strana.`);
      }
      const pages = [];
      for (let pageNumber = 1; pageNumber <= pdf.numPages; pageNumber += 1) {
        const page = await pdf.getPage(pageNumber);
        const viewport = page.getViewport({scale: 2});
        const canvas = document.createElement('canvas');
        canvas.width = Math.ceil(viewport.width);
        canvas.height = Math.ceil(viewport.height);
        const context = canvas.getContext('2d', {alpha: false});
        context.fillStyle = '#ffffff';
        context.fillRect(0, 0, canvas.width, canvas.height);
        await page.render({canvasContext: context, viewport}).promise;
        pages.push(await recognizeWithWorker(worker, canvas));
        page.cleanup();
        canvas.width = 1;
        canvas.height = 1;
      }
      await pdf.destroy();
      return pages.filter(Boolean).join('\n\n');
    } finally {
      await worker.terminate();
    }
  };
})();
