# Microsoft 365: staff sign-in and one-mailbox email for a client's admin site

**Category:** Client admin · **Time needed:** about 2 hours (30 app and sign-in, 20 who gets in, 20 shared mailbox, 30 send limit in Exchange, 20 testing) · **Level:** first-timer friendly, needs a Global Administrator · **Last checked:** 19 November 2026

> **What this sets up.** A small private website for a client's own staff. They sign in with the work accounts they already have in Microsoft 365, only named people get in and the site can send email from one shared "no-reply" mailbox and from no other mailbox in the organisation.
>
> **Use it when** a client needs an internal tool (an admin page, a small back office) and already runs Microsoft 365. There are no new passwords for staff and no separate user list to keep.
>
> **You need:** a Global Administrator login in the client's Microsoft 365, a place to host the site, a password manager and Windows PowerShell for the Exchange part. **Permanent choices:** `Enable-OrganizationCustomization` in Exchange Online cannot be undone (step 6). Everything else can be changed or removed.

Placeholders to replace: `client.example` (the client's email domain), `Client Admin Centre` (the app's name), `no-reply@client.example` (the shared mailbox), `<app client id>`, `<tenant id>` and `<enterprise app object id>`.

## Contents

1. [Words you need first](#1-words-you-need-first)
2. [Big picture](#2-big-picture)
3. [Before you start](#3-before-you-start)
4. [Steps](#4-steps)
5. [Gotchas](#5-gotchas)
6. [Checklist for next time](#6-checklist-for-next-time)
7. [Used on](#7-used-on)
8. [Learning log](#8-learning-log)

---

## 1. Words you need first

| Term | What it means in plain English |
| --- | --- |
| **Microsoft Entra** | Microsoft's directory of people and apps behind Microsoft 365. Admin site: `entra.microsoft.com` |
| **Tenant (directory)** | One organisation's own copy of that directory. Its ID is a long code called the tenant ID |
| **App registration** | The record that says "this website exists and may ask Microsoft to sign people in". It has a client ID (public) and a client secret (private) |
| **Enterprise application** | The same app seen from the organisation's side: who may use it. It has a different Object ID from the app registration |
| **Redirect URI** | The exact address Microsoft sends the person back to after sign-in. It must match to the letter |
| **Client secret** | The site's password to Microsoft. It has a **Value** (the secret, shown once) and a **Secret ID** (a label, not a secret) |
| **Assignment required** | A switch on the enterprise application: only people listed for the app can sign in |
| **Shared mailbox** | A mailbox with no licence and no sign-in of its own, used here as the "from" address |
| **Microsoft Graph** | The web service the site calls to send the email |
| **RBAC for Applications** | The Exchange Online feature that gives an app a mail right for chosen mailboxes only |
| **Management scope** | The Exchange object that says which mailboxes a right covers |

---

## 2. Big picture

```mermaid
flowchart LR
  P[Staff member] -->|work account| MS[Microsoft sign-in<br/>the client's tenant]
  MS -->|1 tenant check<br/>2 listed for the app?| S[Admin site]
  S -->|3 sign-in name ends<br/>@client.example?| OK[Signed in]
  S -->|Graph sendMail<br/>as the app| EX[Exchange Online]
  EX -->|right limited to<br/>one mailbox| NR[no-reply@client.example]
  NR --> R[Recipient]
```

Three separate locks decide who gets in, so one mistake does not open the door:

1. **Single tenant.** Microsoft accepts only accounts from this organisation and the site checks the tenant ID inside the sign-in token.
2. **Named people.** "Assignment required" means only people listed for the app get past Microsoft.
3. **A check in the code.** The sign-in name must end with the client's domain, compared exactly.

---

## 3. Before you start

- [ ] **A Global Administrator login** in the client's Microsoft 365, with its second step working.
- [ ] **The site's address is decided** (for example `admin.client.example`), because the redirect URI is built from it.
- [ ] **A password manager** for the client secret.
- [ ] **A second staff account that is not a Global Administrator** (or someone who has one) for the refusal test in step 4. Without it the test proves nothing (see Gotchas).
- [ ] **The client agrees to the one-off Exchange change** in step 6, if their organisation has never been customised.
- [ ] Decide what the "no-reply" email says about getting help: nobody reads that mailbox, so the email needs a contact line.

---

## 4. Steps

### Step 1. Register the app

In `entra.microsoft.com`, in the client's main directory: **Identity > Applications > App registrations > New registration**.

- Name: `Client Admin Centre`.
- Supported account types: **this organisational directory only** (single tenant).
- Redirect URI: platform **Web**, `https://admin.client.example/api/auth/callback`. Add the hosting provider's own address and `http://localhost:3000/api/auth/callback` as further Web redirect URIs if you test there.

Note the **Application (client) ID** and the **Directory (tenant) ID** from the Overview. Neither is secret.

*Why single tenant:* it is the first lock. Accounts from any other organisation are turned away by Microsoft before your code runs.

### Step 2. Create the client secret

**Certificates & secrets > New client secret**. Give it a name that says where it is used and choose an expiry. Copy the **Value** straight into the password manager and then into the host's settings, marked as sensitive.

*Why at once:* the Value is shown in full only this one time.

### Step 3. Build the sign-in in the site

Use the OpenID Connect authorisation code flow with PKCE against `https://login.microsoftonline.com/<tenant id>/v2.0`. Ask for the scopes `openid profile email`. After Microsoft sends the person back:

- verify the token's signature, issuer, audience and nonce;
- check the token's `tid` equals your tenant ID;
- check `preferred_username` has exactly one `@` and that the part after it equals the client's domain, compared in lower case;
- then set your own signed, HTTP-only session cookie with a short life.

Write the "who is let in" rule as a small pure function with unit tests, including look-alike domains such as `client.example.evil.test` and `notclient.example`.

### Step 4. Limit the app to named people

**Identity > Applications > Enterprise applications > Client Admin Centre**:

- **Properties:** set **Assignment required?** to **Yes** and click **Save**.
- **Users and groups > Add user/group:** add each person who may use the site.

Then test it. Ask someone with an ordinary account that is **not** listed and **not** a Global Administrator to sign in. The correct result is a Microsoft error page with the code `AADSTS50105`.

### Step 5. Create the shared mailbox

In the Microsoft 365 admin centre (`admin.microsoft.com`): **Teams & groups > Shared mailboxes > Add a shared mailbox**. Name it and give it the address `no-reply@client.example`. Add no members.

*Why a shared mailbox:* it needs no licence and nobody can sign in to it.

### Step 6. Let the app send from that mailbox only

Do **not** add the Graph permission `Mail.Send` to the app in Entra. An application permission granted there covers every mailbox in the organisation. Rights given in Entra and in Exchange add up.

Instead give the right in Exchange Online, in Windows PowerShell as the administrator:

```powershell
Install-Module -Name ExchangeOnlineManagement -Scope CurrentUser
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process   # this window only
Connect-ExchangeOnline -UserPrincipalName admin@client.example

# 1 Tell Exchange about the app. The Object ID is the ENTERPRISE application's.
New-ServicePrincipal -AppId <app client id> -ObjectId <enterprise app object id> -DisplayName "Client Admin Centre"

# 2 Only if command 3 below refuses and asks for it. One-off, cannot be undone.
Enable-OrganizationCustomization

# 3 The scope: one mailbox.
New-ManagementScope -Name "No-reply mailbox" -RecipientRestrictionFilter "PrimarySmtpAddress -eq 'no-reply@client.example'"

# 4 The right, for that scope only.
New-ManagementRoleAssignment -App <app client id> -Role "Application Mail.Send" -CustomResourceScope "No-reply mailbox"
```

### Step 7. Prove the limit

```powershell
Test-ServicePrincipalAuthorization -Identity <app client id> -Resource no-reply@client.example | Format-Table
Test-ServicePrincipalAuthorization -Identity <app client id> -Resource someone.else@client.example | Format-Table
Disconnect-ExchangeOnline -Confirm:$false
```

The correct result is **InScope True** for the shared mailbox and **InScope False** for any other. An empty answer means the app has no right at all: command 4 above did not take.

### Step 8. Send from the site

The site gets a Graph token for itself (client credentials, scope `https://graph.microsoft.com/.default`) and calls `POST https://graph.microsoft.com/v1.0/users/no-reply@client.example/sendMail`. A success is the status `202`. Send one real email and read it in an inbox.

---

## 5. Gotchas

- **Global Administrators walk straight through "Assignment required".** Microsoft exempts that role, so a Global Administrator signs in whether listed or not. Testing the lock with an administrator proves nothing. It looks exactly like the lock being off. Use an ordinary account.
- **Secret Value or Secret ID.** The Value is about 40 characters with symbols. The Secret ID is 36 characters with dashes and is never the secret. Pasting the ID gives `AADSTS7000215 Invalid client secret provided`.
- **Two Object IDs.** `New-ServicePrincipal` needs the one from **Enterprise applications**. The one on the **App registrations** page is different, is accepted without complaint and then nothing works.
- **A command can fail and scroll past.** After the Exchange commands, run both tests and read them. On one set-up the service principal and the scope existed but the role assignment did not. The first real send was refused with `403 ErrorAccessDenied`.
- **A new send right can take a while.** Microsoft says 30 minutes to 2 hours. It can also work within minutes. The test command answers at once either way.
- **Windows blocks the Exchange module by default.** `Set-ExecutionPolicy ... -Scope Process` lifts that for the one window and ends when it closes.
- **The host may read settings at build time.** After adding or changing a secret, redeploy before testing.
- **Settings for production only.** Give the secrets to the production environment alone, so a preview build cannot sign people in or send email.
- **Ask for the password every time** (`prompt=login`) if the site can change other people's access.
- **Log the reason, never the secret.** When Microsoft refuses a sign-in, log its error code and first line. For a refused secret, logging its length and shape is enough to tell a Value from a Secret ID.

---

## 6. Checklist for next time

- [ ] App registered as single tenant; redirect URIs for every address used
- [ ] Client secret: the Value, in the password manager and in the host (sensitive, production only); expiry in the calendar
- [ ] Sign-in rule as a tested function: tenant ID and exact domain
- [ ] "Assignment required" Yes and saved; people listed
- [ ] Refusal test done with an ordinary, unlisted account (`AADSTS50105`)
- [ ] Shared mailbox created, no members
- [ ] No `Mail.Send` on the app in Entra
- [ ] Service principal (enterprise Object ID), scope and role assignment in Exchange
- [ ] Both authorisation tests read: True for the mailbox, False for another
- [ ] One real email received
- [ ] Every right the site holds written down in one table for the handover

---

## 7. Used on

- **An internal admin site for a UK client (autumn 2026):** staff sign-in with the client's Microsoft 365, access for named people, email from a shared no-reply mailbox limited with RBAC for Applications. Built and proved in a day, about a third of it spent on the gotchas above.

---

## 8. Learning log

Notes added each time this playbook is used, newest first. Versions and screens change, so check the date.

### 19 Nov 2026 · Microsoft Entra admin centre, Exchange Online PowerShell module V3

- **Design the refusal test around who is exempt.** The first test used an administrator and seemed to show the lock was off. The setting was right all along; the test was wrong.
- **An empty answer is an answer.** `Test-ServicePrincipalAuthorization` printing nothing means no right exists. Read test output before writing "proved" anywhere.
- **Changing a user's sign-in email with Graph** needs the application permission `User.ManageIdentities.All` as well as a user write permission. An update replaces the whole list of sign-in names. Read the list first and swap one entry.
- **Plus addresses make test accounts cheap.** `name+test1@gmail.com` and `name+test2@gmail.com` are different addresses to every system and one inbox to you.
- **Confirm a deploy before saying it is live.** A push can be skipped by the host without an error. Check that the newest build is for the commit just pushed.
- **Sources read on the day:** Microsoft Learn "Properties of an enterprise application", "Role Based Access Control for Applications in Exchange Online", Microsoft Graph "Update user" and "user: sendMail".
