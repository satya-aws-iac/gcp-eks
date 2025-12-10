# Docs for gcp-eks

This `docs/` folder contains a Mermaid architecture diagram and a full project-structure document.

Files:
- `architecture.mmd` — Mermaid diagram describing the repository layout and major Terraform/GKE resources.
- `PROJECT-STRUCTURE.md` — Detailed documentation for the repo, files, scripts, and manual steps.

How to view the diagram:
- On GitHub: open `docs/architecture.mmd` — GitHub renders Mermaid content in Markdown previews.
- Locally: install `mmdc` (mermaid-cli) and run:

```powershell
# Install mermaid-cli (requires Node.js)
npm install -g @mermaid-js/mermaid-cli
# Render to PNG or SVG
mmdc -i docs/architecture.mmd -o docs/architecture.png
```

How to commit these docs:

```powershell
git add docs/
git commit -m "docs: add architecture diagram and project structure"
git push origin stage
```

If you'd like, I can prepare a commit and push on your behalf (you'll need to run the commands locally), or render and add a PNG if you have `mmdc` available and want the binary included in the repo.

**Author**

- Name: Mylavarapu Satyanarayana
- Email: mllsatyanarayana@gmail.com
