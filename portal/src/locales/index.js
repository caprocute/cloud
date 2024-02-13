import en from "./en/en.json";
import enModules from "./en/modules.json";
import es from "./es/es.json";
import esModules from "./es/modules.json";

export const defaultLocale = "en";

export const languages = {
    en: { ...en, ...enModules },
    es: { ...es, ...esModules },
};
