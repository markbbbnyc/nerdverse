# scripts/lib/public_names.sh — Random pilgrim/companion names for public registration.
# Author canon (Meyiu / Sera) lives in 002_fresh_game.sql for local dev only.

_PUBLIC_PILGRIMS=(
    Calder Bryn Rook Alden Thess Corin Ulric Petra Ivo Kest Wynn Torren Syl Bran
    Madden Orla Pike Jessen Holt Varrow Greer
)

_PUBLIC_COMPANIONS=(
    Lio Maren Vesper Quinn Isolde Bram Niko Tamsin Orin Elowen Rowan Cade
    Fen Mirren Sable Dara Kell Asha
)

_PUBLIC_EPITHETS=(
    "The Road-Worn Listener"
    "The Quiet Ember"
    "The Last Honest Bargain"
    "The Lantern at Dusk"
    "The Ash-Blooded Walker"
    "The Patient Blade"
    "The One Who Returned Once"
    "The Keeper of Small Fires"
    "The Slow-Burning Oath"
)

_PUBLIC_SURNAMES=(
    Ashvale Rookwind Thornmere Greymoss Brackenfold Stonetread Fairholt
    Millwright Colden Ashwick Bramblegate
)

_public_pick_pilgrim() {
    local n=${#_PUBLIC_PILGRIMS[@]}
    printf '%s' "${_PUBLIC_PILGRIMS[$(( RANDOM % n ))]}"
}

_public_pick_companion() {
    local n=${#_PUBLIC_COMPANIONS[@]}
    printf '%s' "${_PUBLIC_COMPANIONS[$(( RANDOM % n ))]}"
}

_public_pick_epithet() {
    local n=${#_PUBLIC_EPITHETS[@]}
    printf '%s' "${_PUBLIC_EPITHETS[$(( RANDOM % n ))]}"
}

_public_pick_surname() {
    local n=${#_PUBLIC_SURNAMES[@]}
    printf '%s' "${_PUBLIC_SURNAMES[$(( RANDOM % n ))]}"
}

# Emit: player<TAB>companion<TAB>epithet<TAB>surname (companion != player)
cc_public_random_defaults() {
    local player companion epithet surname tries=0
    player=$(_public_pick_pilgrim)
    companion=$(_public_pick_companion)
    while [[ "$companion" == "$player" && $tries -lt 8 ]]; do
        companion=$(_public_pick_companion)
        tries=$(( tries + 1 ))
    done
    epithet=$(_public_pick_epithet)
    surname=$(_public_pick_surname)
    printf '%s\t%s\t%s\t%s' "$player" "$companion" "$epithet" "$surname"
}