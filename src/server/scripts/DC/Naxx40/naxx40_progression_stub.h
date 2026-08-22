/* Minimal stub for IndividualProgression used by scripts
 * Provides `sIndividualProgression` and a default `doableNaxx40Bosses = false`.
 */
#ifndef DC_NAXX40_PROGRESSION_STUB_H
#define DC_NAXX40_PROGRESSION_STUB_H

class Player;

class IndividualProgression
{
public:
    IndividualProgression();

    bool doableNaxx40Bosses;
    bool requireNaxxStrath;

    bool hasPassedProgression(Player* /*player*/, int /*progression*/) const { return false; }
    bool isExcludedFromProgression(Player* /*player*/) const { return false; }
    bool isAttuned(Player* /*player*/) const { return false; }
};

// Global pointer used across the scripts
extern IndividualProgression* sIndividualProgression;

#endif // DC_NAXX40_PROGRESSION_STUB_H
