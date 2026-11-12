<h1 align="center"> Security Policy </h1>

<div align="center">
  <p>Protecting the X Linux web infrastructure and package distribution system</p>
</div>

<hr />

<h2 align="center" id="reporting-vulnerabilities"> Reporting Security Vulnerabilities </h2>

<p>If you discover a security vulnerability in the <b>X Linux Website</b> (Next.js exploits, SSR vulnerabilities) or the <b>System Packages</b> (repository database integrity, <code>x-release</code> hooks), please report it responsibly via email to:</p>

<p align="center">
  <b>Email:</b> <a href="mailto:x@xscriptor.com">x@xscriptor.com</a>
</p>

<blockquote>
  <b>Do not</b> open public GitHub issues for security vulnerabilities. Private disclosure allows us to fix the issue before it can be exploited.
</blockquote>

<h3 align="center"> What to Include </h3>
<p>When reporting a security issue, please provide:</p>
<ol>
  <li><b>Description</b> — A clear explanation of the vulnerability.</li>
  <li><b>Type</b> — The category of the issue (e.g., XSS, Repository Injection, Sensitive Data Exposure).</li>
  <li><b>Steps to Reproduce</b> — Detailed steps or a Proof of Concept (PoC) to trigger the vulnerability.</li>
  <li><b>Impact</b> — How severe is the issue? Could it compromise the website or the users' systems?</li>
  <li><b>Affected Component</b> — Which part is affected? (e.g., the Next.js frontend or the <code>build-repo.sh</code> logic).</li>
</ol>

<h3 align="center"> Guidelines </h3>
<ul>
  <li><b>Confidentiality</b> — Do not disclose the vulnerability publicly until a fix is released.</li>
  <li><b>Patience</b> — Please give the maintainers reasonable time to address the issue before public disclosure.</li>
  <li><b>Response Time</b> — We aim to acknowledge receipt within <b>7 days</b>.</li>
</ul>

<hr />

<h2 align="center" id="best-practices"> Security Best Practices </h2>

<p>For developers and maintainers of the X Repo:</p>
<ul>
  <li><b>Web Security</b> — Always keep Next.js dependencies updated and sanitize any user-provided data in the <code>app/</code> routes.</li>
  <li><b>Package Integrity</b> — Ensure <code>XBUILD</code> and <code>PKGBUILD</code> files do not download binaries from untrusted third-party sources.</li>
  <li><b>Repository Signing</b> — Maintain the security of the GPG keys used to sign the <code>[x]</code> repository database.</li>
  <li><b>Environment Variables</b> — Never hardcode API keys or private tokens in the website source code; use <code>.env</code> files (git-ignored).</li>
</ul>

<hr />

<h2 align="center" id="supported-versions"> Supported Versions </h2>

<table align="center">
  <thead>
    <tr>
      <th>Component</th>
      <th>Status</th>
      <th>Support Until</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td align="center">Website (Main Branch)</td>
      <td align="center">Active</td>
      <td align="center">latest</td>
    </tr>
    <tr>
      <td align="center">System Packages</td>
      <td align="center">Active</td>
      <td align="center">Rolling Release</td>
    </tr>
  </tbody>
</table>

<hr />

<div align="center">
  <p><b>Thank you for helping keep the X Linux infrastructure secure!</b></p>
</div>