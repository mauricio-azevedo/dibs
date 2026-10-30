package io.github.mauricioazevedo.dibs;

import org.springframework.boot.SpringApplication;

public class TestDibsApplication {

  public static void main(String[] args) {
    SpringApplication.from(DibsApplication::main).with(TestcontainersConfiguration.class).run(args);
  }
}
