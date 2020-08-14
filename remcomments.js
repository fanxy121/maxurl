const fs = require("fs");
// git clone the gh-pages branch into site
const about = require("./site/about.js");

function update() {
  console.log("Updating...");
  var userscript = fs.readFileSync(process.argv[2] || "userscript.user.js").toString();
  var lines = userscript.split("\n");

  if (lines.length < 65000) {
    console.log("Incomplete");
    return;
  }

  var newlines = [];
  var in_bigimage = false;
  var in_falserule = false;

  var firstcomment = true;
  var within_header = true;
  var within_firstcomment = false;
  for (const line of lines) {
    if (!in_bigimage) {
      if (firstcomment) {
        if (line.match(/^\s*\/\//)) {
          if (line.match(/==\/UserScript==/)) {
            within_header = false;
          } else if (!within_header) {
            within_firstcomment = true;
          }
        } else if (within_firstcomment) {
          firstcomment = false;
          newlines.push("");
          newlines.push("// Due to Greasyfork's 2MB limit, all comments within bigimage() had to be removed");
          newlines.push("// You can view the original source code here: https://github.com/qsniyg/maxurl/blob/master/userscript.user.js");
        }
      }

      if (line.match(/^\s+\/\/ -- start bigimage --/))
        in_bigimage = true;
      newlines.push(line);
      continue;
    }

    if (line.match(/^\s+\/\/ -- end bigimage --/)) {
      newlines.push(line);
      in_bigimage = false;
      continue;
    }

    if (in_falserule) {
      if (line.match(/^\t{2}[}](?:[*][/])?$/))
        in_falserule = false;
      continue;
    }

    if (!line.match(/^\s*\/\//)) {
      var exclude_false = true;
      if (exclude_false && line.match(/^\t{2}(?:[/][*])?if [(]false *&&/)) {
        in_falserule = true;
        continue;
      } else {
        // TODO: If needed, /^ {8}/ can later be removed (about.js will have to be updated)
        newlines.push(line);
      }
    } else {
      if (!line.match(/\/\/\s+https?:\/\//) && false)
        console.log(line);
    }
  }

  var newcontents = newlines.join("\n");
  fs.writeFileSync("userscript_smaller.user.js", newcontents);

  about.get_userscript_stats(newcontents);
  var sites = about.get_sites();

  var sites_header = [
    "# This is an automatically generated list of every hardcoded website currently supported by the script.",
    "#",
    "# Hardcoded websites are (usually) websites that need custom logic that cannot be represented",
    "#  in a generic rule.",
    "#",
    "# The script supports many generic rules (such as for Wordpress, MediaWiki, and Drupal),",
    "#  which means that even if a website is not this list, the script may still support it.",
    "#",
    "# The script also (usually) only cares about the domain containing images, not the host website.",
    "#  For example, 'pinterest.com' is not in this list, but 'pinimg.com' (where Pinterest's images are stored) is.",
    "#",
    "# I usually don't visit the host websites (only the image links themselves), so there are sometimes cases",
    "#  where rules don't work for all images under the website.",
    "#  If you spot any issues, please leave an issue on Github, and I will try to fix it as soon as I can.",
    "#",
    "# There is currently no automatic testing, which means it's possible some of these don't work anymore.",
    "#  Please let me know if you find a website that doesn't work!",
    ""
  ];

  [].push.apply(sites_header, sites);
  sites_header.push("");

  fs.writeFileSync("sites.txt", sites_header.join("\n"));

  console.log("Done");
}

update();
console.log("");
console.log("Watching");
fs.watchFile("userscript.user.js", update);
