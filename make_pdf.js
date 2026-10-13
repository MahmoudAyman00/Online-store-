const { mdToPdf } = require('md-to-pdf');
const fs = require('fs');
(async () => {
  const pdf = await mdToPdf(
    { path: 'APP_REPORT.md' },
    {
      stylesheet: 'report.css',
      pdf_options: {
        format: 'A4',
        margin: { top: '18mm', bottom: '18mm', right: '14mm', left: '14mm' },
      },
      launch_options: { args: ['--no-sandbox'] },
    }
  );
  if (pdf) {
    fs.writeFileSync('APP_REPORT.pdf', pdf.content);
    console.log('PDF_OK ' + pdf.content.length + ' bytes');
  }
})().catch((e) => { console.error('PDF_FAIL ' + e.message); process.exit(1); });
