package io.github.mauricioazevedo.dibs;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.methods;
import static com.tngtech.archunit.library.Architectures.layeredArchitecture;

import com.tngtech.archunit.core.domain.JavaClasses;
import com.tngtech.archunit.core.importer.ClassFileImporter;
import com.tngtech.archunit.core.importer.ImportOption;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.annotation.Transactional;

/** The structure CONTRIBUTING's Stack section describes, checked on every unit run. */
class ArchitectureTest {

  private static final String ROOT = "io.github.mauricioazevedo.dibs";
  private static final JavaClasses production =
      new ClassFileImporter()
          .withImportOption(ImportOption.Predefined.DO_NOT_INCLUDE_TESTS)
          .importPackages(ROOT);

  @Test
  void domainImportsNoFramework() {
    classes()
        .that()
        .resideInAPackage(ROOT + ".domain..")
        .should()
        .onlyDependOnClassesThat()
        .resideInAnyPackage("java..", ROOT + ".domain..")
        .because("a domain type that imports a framework can only be tested with it booted")
        .allowEmptyShould(true)
        .check(production);
  }

  @Test
  void dependenciesPointInward() {
    layeredArchitecture()
        .consideringOnlyDependenciesInLayers()
        .withOptionalLayers(true)
        .layer("domain")
        .definedBy(ROOT + ".domain..")
        .layer("application")
        .definedBy(ROOT + ".application..")
        .layer("web")
        .definedBy(ROOT + ".adapter.web..")
        .layer("persistence")
        .definedBy(ROOT + ".adapter.persistence..")
        .whereLayer("web")
        .mayNotBeAccessedByAnyLayer()
        .whereLayer("persistence")
        .mayNotBeAccessedByAnyLayer()
        .whereLayer("application")
        .mayOnlyBeAccessedByLayers("web")
        .whereLayer("domain")
        .mayOnlyBeAccessedByLayers("application", "web", "persistence")
        .because("adapters depend on the core, never the reverse, and never on each other")
        .allowEmptyShould(true)
        .check(production);
  }

  @Test
  void transactionsLiveInTheApplicationLayer() {
    classes()
        .that()
        .areAnnotatedWith(Transactional.class)
        .should()
        .resideInAPackage(ROOT + ".application..")
        .because("a transaction on a controller or a repository spans too much or too little")
        .allowEmptyShould(true)
        .check(production);
    methods()
        .that()
        .areAnnotatedWith(Transactional.class)
        .should()
        .beDeclaredInClassesThat()
        .resideInAPackage(ROOT + ".application..")
        .because("a transaction on a controller or a repository spans too much or too little")
        .allowEmptyShould(true)
        .check(production);
  }
}
