# Agent instructions

## CHECKLIST.md

This repo (the generic module library) has no `CHECKLIST.md` of its own —
it doesn't deploy anything, so there's no deployment contract to keep in
sync. The private overlay repo (`dotfiles_nix_personal`) owns the real
`CHECKLIST.md`. When you add, remove, or change any deployment step there —
secret provisioning, deployment tooling, CI workflow changes, new host
requirements, or anything else a human would need to do manually — update
that repo's `CHECKLIST.md` in the same change. Every diff that touches how
the system is deployed should have a matching diff in the checklist.