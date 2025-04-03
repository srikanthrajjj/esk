const fs = require('fs');

try {
  const file = 'src/App.tsx';
  let content = fs.readFileSync(file, 'utf8');
  
  // Get the problematic section
  const lines = content.split('
');
  
  // Fix the JSX structure around line 1340
  if (lines.length > 1342) {
    // Remove problematic lines and add corrected syntax
    const newLines = [
      ...lines.slice(0, 1338),
      '              </div>',
      '            )}',
      '',
      '            {activeTab === \'appointments\' && (',
      ...lines.slice(1342)
    ];
    
    // Write the fixed content back
    fs.writeFileSync(file, newLines.join('
'), 'utf8');
    console.log('Fixed JSX syntax at line 1340');
  } else {
    console.error('File too short, could not find the problematic section');
  }
} catch (err) {
  console.error('Error:', err);
}
